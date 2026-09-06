class ManualArtistAdder
  SPOTIFY_URL_ID = %r{open\.spotify\.com/(?:intl-\w+/)?artist/([a-zA-Z0-9]+)}.freeze

  def initialize(user)
    @user = user
  end

  def add(input)
    input = input.to_s.strip
    spotify_id_from_url = input[SPOTIFY_URL_ID, 1]

    if spotify_id_from_url
      add_by_spotify_id(spotify_id_from_url)
    else
      add_by_name(input)
    end
  end

  private

  def add_by_spotify_id(spotify_id)
    if (existing = @user.top_artists.find_by(spotify_id: spotify_id))
      return existing
    end

    match = SpotifyThrottle.call { RSpotify::Artist.find(spotify_id) } rescue nil

    record = @user.top_artists.new(spotify_id: spotify_id)
    if match
      record.name            = match.name
      record.name_normalized = Concert.normalize_name(match.name)
      record.image_url       = match.images&.first&.[]("url")
      record.genres          = fetch_tags(match.name)
    else
      # Spotify wasn't reachable — save with a placeholder name so the backfill
      # step in the sync job can complete it once the rate-limit lifts.
      record.name            = "In afwachting van Spotify…"
      record.name_normalized = "spotify:#{spotify_id}"
    end
    record.manual  = true
    record.best_rank = 500

    record.save
    record
  end

  def self.pending_enrichment_scope(user)
    user.top_artists.where("name_normalized LIKE 'spotify:%'")
  end

  def add_by_name(name)
    normalized = Concert.normalize_name(name)
    if (existing = @user.top_artists.find_by(name_normalized: normalized))
      return existing
    end

    match = safe_spotify_search(name, normalized)
    spotify_id = match&.id || "manual:#{normalized}"

    record = @user.top_artists.find_or_initialize_by(spotify_id: spotify_id)
    record.assign_attributes(
      name:            match&.name || name,
      name_normalized: normalized,
      image_url:       match&.images&.first&.[]("url"),
      manual:          true,
      best_rank:       500
    )
    record.genres = fetch_tags(record.name)

    record.save
    record
  end

  def fetch_tags(name)
    tags = LastfmClient.enabled? ? LastfmClient.tags(name) : []
    tags.empty? ? ArtistTags.tags_for(name) : tags
  end

  def safe_spotify_search(name, normalized)
    results = SpotifyThrottle.call { RSpotify::Artist.search(name, limit: 5) }
    results.find { |r| Concert.normalize_name(r.name) == normalized } || results.first
  rescue => e
    Rails.logger.warn("ManualArtistAdder search failed for #{name}: #{e.class} #{e.message}")
    nil
  end
end
