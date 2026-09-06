class FetchConcertsForUserJob < ApplicationJob
  queue_as :default

  ADAPTERS = [
    Adapters::Ticketmaster,
    Adapters::Metalagenda,
    Adapters::Podiuminfo,
    Adapters::Festivalinfo
  ].freeze

  # Spotify errors we can shrug off if we already have a cached library.
  SPOTIFY_TRANSIENT = [
    RestClient::TooManyRequests,
    RestClient::ServiceUnavailable,
    RestClient::Unauthorized,
    RestClient::InternalServerError,
    RestClient::BadGateway,
    RestClient::GatewayTimeout,
    RestClient::RequestTimeout,
    SocketError,
    Errno::ECONNRESET,
    OpenSSL::SSL::SSLError,
    Timeout::Error
  ].freeze

  def perform(user_id)
    user = User.find(user_id)

    backfill_manual_artists(user)
    sync_spotify_library(user) if user.library_stale?

    hidden_ids = user.hidden_artists.pluck(:spotify_artist_id)
    artists = user.top_artists.where.not(spotify_id: hidden_ids)

    if artists.empty?
      Rails.logger.warn("FetchConcertsForUserJob: no top artists for user #{user.id}; skipping adapters")
    else
      ADAPTERS.select(&:enabled?).each do |adapter_class|
        begin
          adapter_class.new.run_for_user(user, artists)
        rescue => e
          Rails.logger.warn("Adapter #{adapter_class} failed: #{e.class} #{e.message}")
        end
      end
    end

    user.update!(concerts_synced_at: Time.current, concerts_syncing_since: nil)
  rescue => e
    user&.update!(concerts_syncing_since: nil)
    raise
  end

  private

  def backfill_manual_artists(user)
    ManualArtistAdder.pending_enrichment_scope(user).find_each do |record|
      match = SpotifyThrottle.call { RSpotify::Artist.find(record.spotify_id) }
      next unless match

      record.update!(
        name:            match.name,
        name_normalized: Concert.normalize_name(match.name),
        image_url:       match.images&.first&.[]("url"),
        genres:          LastfmClient.enabled? ? LastfmClient.tags(match.name) : ArtistTags.tags_for(match.name)
      )
    rescue SpotifyThrottle::CoolingDown => e
      Rails.logger.warn("Backfill paused: #{e.message}")
      break
    rescue => e
      Rails.logger.warn("Backfill failed for #{record.spotify_id}: #{e.class} #{e.message}")
    end
  end

  def sync_spotify_library(user)
    SpotifyLibrary.new(user).sync!
  rescue *SPOTIFY_TRANSIENT => e
    if user.top_artists.exists?
      Rails.logger.warn("Spotify sync failed (#{e.class}): using cached library of #{user.top_artists.count} artists")
    else
      raise
    end
  end
end
