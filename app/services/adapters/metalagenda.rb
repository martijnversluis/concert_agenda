module Adapters
  class Metalagenda < BaseAdapter
    URL = "https://www.metalagenda.nl/ajax.php".freeze
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze
    DISCOVERY_LOOKUP_LIMIT = 60

    def self.enabled?
      true
    end

    TRIBUTE_MARKERS = /\b(tribute|cover(-|\s)?band|hommage|the ultimate|meets|voor beginners|by night)\b/i.freeze
    TITLE_TRIBUTE_PREFIX = /^\s*cover\s*\/\s*tribute\s*/i.freeze

    def run_for_user(user, artists)
      known_names = artists.pluck(:name_normalized).to_set
      top_genres  = user.top_artists.flat_map { |a| Array(a.genres) }.uniq.first(20).to_set

      # Pass 1: known-artist matches (including tributes to those artists)
      events.each do |event|
        event[:bands].each do |band|
          next unless known_names.include?(Concert.normalize_name(band))
          save_event_band(event, band)
        end
      end

      # Pass 2: discovery — look up genre for unknown headliners,
      # save as concert if their tags overlap with the user's top genres.
      return if top_genres.empty?
      discovery_pass(known_names, top_genres)
    end

    def events
      @events ||= parse(fetch_html).select { |e| e[:date] <= Concert.agenda_end_date }
    end

    private

    def discovery_pass(known_names, top_genres)
      lookups = 0
      seen = Set.new

      events.each do |event|
        break if lookups >= DISCOVERY_LOOKUP_LIMIT

        headliner = event[:bands].first
        next if headliner.blank?
        norm = Concert.normalize_name(headliner)
        next if known_names.include?(norm)
        next if seen.include?(norm)
        seen << norm

        artist = ArtistResolver.resolve(headliner)
        # Only count against the throttle budget if MusicBrainz was actually hit
        # (cached artists come back instantly).
        lookups += 1 if artist.updated_at > 5.seconds.ago

        next if artist.genres.blank?
        next if (artist.genres.to_set & top_genres).empty?
        save_event_band(event, headliner)
      end
    end

    def save_event_band(event, band_name)
      is_tribute = event[:title].to_s.match?(TRIBUTE_MARKERS)
      cover_band = is_tribute ? extract_cover_band(event[:title], band_name) : nil

      upsert_concert(
        external_id: "#{event[:id]}:#{Concert.normalize_name(band_name)}",
        title:       event[:title],
        artist_name: band_name,
        starts_on:   event[:date],
        venue_name:  event[:venue],
        venue_city:  event[:city],
        venue_country: "NL",
        url:         event[:url],
        tribute:     is_tribute,
        cover_band_name: cover_band
      )
    end

    # From "cover / tribute FEUERENGEL: A Tribute to Rammstein ..." → "FEUERENGEL"
    def extract_cover_band(title, original)
      t = title.to_s.sub(TITLE_TRIBUTE_PREFIX, "")
      candidate = t.split(":", 2).first.to_s
      candidate = candidate.split(/\s+-\s+/).first.to_s
      candidate = candidate.split(/\s+(?:a\s+tribute|feat\.?|met|w\/|,)/i).first.to_s
      candidate.strip!
      return nil if candidate.blank? || candidate.length > 60
      return nil if Concert.normalize_name(candidate) == Concert.normalize_name(original)
      candidate
    end

    def fetch_html
      response = HTTParty.post(URL,
        headers: {
          "User-Agent"       => USER_AGENT,
          "Referer"          => "https://www.metalagenda.nl/",
          "Origin"           => "https://www.metalagenda.nl",
          "X-Requested-With" => "XMLHttpRequest",
          "Accept"           => "*/*",
          "Accept-Language"  => "nl-NL,nl;q=0.9,en;q=0.8"
        },
        body: { action: "load_agenda" }
      )
      response.success? ? response.body : ""
    rescue => e
      Rails.logger.warn("Metalagenda fetch failed: #{e.class} #{e.message}")
      ""
    end

    def parse(html)
      return [] if html.blank?

      doc = Nokogiri::HTML.fragment(html)
      current_date = nil
      out = []

      doc.css("#cont_left > *").each do |node|
        classes = (node["class"] || "").split
        if classes.include?("dateheader") && node["id"].present?
          current_date = Date.parse(node["id"]) rescue nil
        elsif classes.include?("agendapunt") && current_date
          entry = extract_event(node, current_date)
          out << entry if entry
        end
      end

      out
    end

    def extract_event(node, date)
      left = node.at_css(".left") or return nil

      title_link = left.at_css("> a")
      title      = left.at_css("h3")&.text&.gsub(/uitverkocht/i, "")&.strip
      url        = title_link&.[]("href")

      venue = left.css("> a").find { |a| a["href"].to_s.start_with?("/venues/") }&.text&.strip
      city  = left.css("> a").find { |a| a["href"].to_s.start_with?("/p/") }&.text&.strip&.capitalize

      bands_container = left.css("div").find { |d| d.text.strip.start_with?("Bands:") }
      bands = extract_bands(bands_container)

      ical = node.at_css("a[href^='/ical/']")
      id   = ical&.[]("href")&.match(%r{/ical/(\d+)})&.[](1)

      return nil if bands.empty? || id.nil?

      {
        id:    id,
        title: title,
        url:   url,
        venue: venue,
        city:  city,
        date:  date,
        bands: bands
      }
    end

    def extract_bands(container)
      return [] unless container
      raw = container.text.sub(/\ABands:\s*/, "")
      raw.split("|").map(&:strip).reject(&:empty?)
    end
  end
end
