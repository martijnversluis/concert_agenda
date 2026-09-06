class TopArtist < ApplicationRecord
  belongs_to :user

  validates :spotify_id, :name, :name_normalized, presence: true
  validates :spotify_id, uniqueness: { scope: :user_id }

  scope :visible, ->(user) {
    hidden = user.hidden_artists.pluck(:spotify_artist_id)
    hidden.empty? ? all : where.not(spotify_id: hidden)
  }
end
