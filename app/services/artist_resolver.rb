class ArtistResolver
  REFRESH_AFTER = 30.days

  def self.resolve(name)
    normalized = Concert.normalize_name(name)
    existing = Artist.find_by(name_normalized: normalized)

    if existing&.spotify_looked_up_at.present? && existing.spotify_looked_up_at > REFRESH_AFTER.ago
      return existing
    end

    look_up(existing, name, normalized)
  end

  def self.look_up(existing, name, normalized)
    spotify_match = search_spotify(name, normalized)

    # If Spotify identifies this artist as one we've already cached by another
    # normalized name, use that record and merge.
    if spotify_match
      by_spotify = Artist.find_by(spotify_id: spotify_match.id)
      if by_spotify && by_spotify.id != existing&.id
        existing&.destroy
        return enrich!(by_spotify, spotify_match, name)
      end
    end

    artist = existing || Artist.new(name: name, name_normalized: normalized)
    if spotify_match
      artist.spotify_id = spotify_match.id
      artist.image_url  ||= spotify_match.images&.first&.[]("url")
    end
    enrich!(artist, spotify_match, name)
  rescue => e
    Rails.logger.warn("ArtistResolver failed for #{name}: #{e.class} #{e.message}")
    fallback = existing || Artist.for_concert_name(name)
    fallback.update!(spotify_looked_up_at: Time.current)
    fallback
  end

  def self.search_spotify(name, normalized)
    results = SpotifyThrottle.call { RSpotify::Artist.search(name, limit: 5) }
    results.find { |r| Concert.normalize_name(r.name) == normalized } || results.first
  end

  def self.enrich!(artist, spotify_match, name)
    if artist.genres.blank?
      artist.genres = fetch_tags(name)
    end
    if artist.similar_artist_names.blank? && LastfmClient.enabled?
      artist.similar_artist_names = LastfmClient.similar(name).map { |n| Concert.normalize_name(n) }
    end
    artist.spotify_looked_up_at = Time.current
    artist.save!
    artist
  end

  def self.fetch_tags(name)
    tags = LastfmClient.enabled? ? LastfmClient.tags(name) : []
    tags = ArtistTags.tags_for(name) if tags.empty?
    tags
  end
end
