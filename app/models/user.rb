class User < ApplicationRecord
  has_many :hidden_artists, dependent: :destroy
  has_many :top_artists,    dependent: :destroy

  def concerts_stale?
    concerts_synced_at.nil? || concerts_synced_at < 6.hours.ago
  end

  def library_stale?
    top_artists.empty? ||
      (concerts_synced_at.present? && concerts_synced_at < 24.hours.ago) ||
      concerts_synced_at.nil?
  end

  def concerts_syncing?
    concerts_syncing_since.present? && concerts_syncing_since > 10.minutes.ago
  end

  def self.from_omniauth(auth)
    find_or_initialize_by(spotify_id: auth.uid).tap do |user|
      user.display_name     = auth.info.name
      user.email            = auth.info.email
      user.image_url        = auth.info.image
      user.access_token     = auth.credentials.token
      user.refresh_token    = auth.credentials.refresh_token if auth.credentials.refresh_token.present?
      user.token_expires_at = Time.zone.at(auth.credentials.expires_at) if auth.credentials.expires_at
      user.save!
    end
  end

  def token_expired?
    token_expires_at.present? && token_expires_at <= Time.current
  end
end
