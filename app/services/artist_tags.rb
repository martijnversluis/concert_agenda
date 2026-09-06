class ArtistTags
  BASE = "https://www.theaudiodb.com/api/v1/json/2/search.php".freeze
  RATE_LIMIT_INTERVAL = 0.4

  @@last_call = 0.0
  @@mutex = Mutex.new

  # Coarse tags per artist from TheAudioDB (free, no key).
  # Returns lowercase strings, deduped, max 3.
  def self.tags_for(name)
    throttle!

    response = HTTParty.get(BASE, query: { s: name }, timeout: 8)
    return [] unless response.success?

    artists = response["artists"] || []
    return [] if artists.blank?

    lowered = name.downcase
    artist = artists.find { |a| a["strArtist"].to_s.downcase == lowered } || artists.first
    return [] unless artist

    raw = [artist["strStyle"], artist["strGenre"]]
            .compact
            .flat_map { |v| v.to_s.split(/[,\/]/) }
            .map { |v| v.strip.downcase }
    GenreFilter.clean(raw).first(3)
  rescue => e
    Rails.logger.warn("ArtistTags failed for #{name}: #{e.class} #{e.message}")
    []
  end

  def self.throttle!
    @@mutex.synchronize do
      elapsed = Time.now.to_f - @@last_call
      sleep(RATE_LIMIT_INTERVAL - elapsed) if elapsed < RATE_LIMIT_INTERVAL
      @@last_call = Time.now.to_f
    end
  end
end
