class SpotifyLibrary
  TIME_RANGES = %w[short_term medium_term long_term].freeze

  def initialize(user)
    @user = user
  end

  # Fetch from Spotify and upsert TopArtist rows for this user.
  def sync!
    ranked = ranked_artists

    ranked.each_value do |entry|
      artist = entry[:artist]
      next if artist.id.blank? || artist.name.blank?

      normalized = Concert.normalize_name(artist.name)
      next if normalized.blank?

      record = @user.top_artists.find_or_initialize_by(spotify_id: artist.id)
      record.assign_attributes(
        name:            artist.name,
        name_normalized: normalized,
        image_url:       artist.images.first&.[]("url"),
        best_rank:       entry[:rank]
      )
      if record.genres.blank?
        record.genres = LastfmClient.enabled? ? LastfmClient.tags(artist.name) : []
        record.genres = ArtistTags.tags_for(artist.name) if record.genres.empty?
      end
      begin
        record.save!
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("SpotifyLibrary skip #{artist.name.inspect}: #{e.message}")
      end
    end

    seen_ids = ranked.keys
    if seen_ids.any?
      @user.top_artists.where.not(spotify_id: seen_ids).where(manual: false).delete_all
    end
  end

  # Combined artist list from all three top-artist windows plus followed artists.
  # Deduped by id. Ranked by best (lowest) rank observed across windows;
  # followed-only artists sort after ranked ones.
  def all_artists
    ranked_artists.values
      .sort_by { |e| [e[:rank], e[:artist].name.downcase] }
      .map { |e| e[:artist] }
  end

  def ranked_artists
    spotify_user = build_spotify_user
    ranked = {}

    TIME_RANGES.each do |range|
      safe_fetch("top_artists(#{range})") do
        SpotifyThrottle.call { spotify_user.top_artists(limit: 50, time_range: range) }.each_with_index do |artist, i|
          ranked[artist.id] ||= { artist: artist, rank: Float::INFINITY }
          ranked[artist.id][:rank] = [ranked[artist.id][:rank], i + 1].min
        end
      end
    end

    TIME_RANGES.each do |range|
      safe_fetch("top_tracks(#{range})") do
        SpotifyThrottle.call { spotify_user.top_tracks(limit: 50, time_range: range) }.each_with_index do |track, i|
          Array(track.artists).each do |artist|
            ranked[artist.id] ||= { artist: artist, rank: 100 + i }
          end
        end
      end
    end

    fetch_followed(spotify_user).each do |artist|
      ranked[artist.id] ||= { artist: artist, rank: 999 }
    end

    ranked
  end

  def safe_fetch(label)
    yield
  rescue => e
    Rails.logger.warn("SpotifyLibrary #{label} failed: #{e.class} #{e.message}")
  end

  private

  def build_spotify_user
    SpotifyTokenRefresher.new(@user).ensure_fresh!
    RSpotify::User.new(
      "credentials" => {
        "token" => @user.access_token,
        "refresh_token" => @user.refresh_token,
        "access_refresh_callback" => ->(new_token, expires_at) {
          @user.update!(access_token: new_token, token_expires_at: Time.zone.at(expires_at))
        }
      },
      "id" => @user.spotify_id
    )
  end

  def fetch_followed(spotify_user)
    all = []
    after = nil
    loop do
      opts = { limit: 50 }
      opts[:after] = after if after
      batch = SpotifyThrottle.call { spotify_user.following(type: "artist", **opts) }
      break if batch.blank?
      all.concat(batch)
      break if batch.size < 50
      after = batch.last.id
    end
    all
  rescue => e
    Rails.logger.warn("SpotifyLibrary#fetch_followed failed: #{e.class}: #{e.message}")
    []
  end
end
