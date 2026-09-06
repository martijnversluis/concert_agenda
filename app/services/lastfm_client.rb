class LastfmClient
  BASE = "https://ws.audioscrobbler.com/2.0/".freeze
  RATE_LIMIT_INTERVAL = 0.25

  @@last_call = 0.0
  @@mutex = Mutex.new

  def self.enabled?
    ENV["LASTFM_API_KEY"].present?
  end

  # Returns up to `limit` names of artists Last.fm considers similar,
  # sorted by their match score. Names are Last.fm's canonical spelling.
  def self.similar(name, limit: 25)
    return [] unless enabled?

    body = call(method: "artist.getSimilar", artist: name, limit: limit)
    (body.dig("similarartists", "artist") || []).map { |a| a["name"] }.compact
  rescue => e
    Rails.logger.warn("LastfmClient.similar failed for #{name}: #{e.class} #{e.message}")
    []
  end

  # Returns up to `limit` genre-like tags (lowercased), Last.fm-weighted.
  def self.tags(name, limit: 6)
    return [] unless enabled?

    body = call(method: "artist.getTopTags", artist: name)
    tags = body.dig("toptags", "tag") || []
    GenreFilter.clean(tags.map { |t| t["name"].to_s.downcase }).first(limit)
  rescue => e
    Rails.logger.warn("LastfmClient.tags failed for #{name}: #{e.class} #{e.message}")
    []
  end

  def self.call(params)
    throttle!
    HTTParty.get(BASE, query: params.merge(
      api_key: ENV["LASTFM_API_KEY"],
      format:  "json",
      autocorrect: 1
    ), timeout: 8)
  end

  def self.throttle!
    @@mutex.synchronize do
      elapsed = Time.now.to_f - @@last_call
      sleep(RATE_LIMIT_INTERVAL - elapsed) if elapsed < RATE_LIMIT_INTERVAL
      @@last_call = Time.now.to_f
    end
  end
end
