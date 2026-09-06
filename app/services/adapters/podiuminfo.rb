module Adapters
  class Podiuminfo < BaseAdapter
    BASE = "https://www.podiuminfo.nl/concertagenda/".freeze
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze
    MAX_PAGES = 8
    DISCOVERY_LOOKUP_LIMIT = 80

    def self.enabled?
      true
    end

    def run_for_user(user, artists)
      known_names = artists.pluck(:name_normalized).to_set
      top_genres  = user.top_artists.flat_map { |a| Array(a.genres) }.uniq.first(20).to_set

      events.each do |event|
        event[:performers].each do |performer|
          next unless known_names.include?(Concert.normalize_name(performer[:name]))
          save_event_performer(event, performer)
        end
      end

      return if top_genres.empty?
      discovery_pass(known_names, top_genres)
    end

    def events
      @events ||= fetch_pages.select { |e| e[:date] && e[:date] <= Concert.agenda_end_date }
    end

    private

    def discovery_pass(known_names, top_genres)
      lookups = 0
      seen = Set.new

      events.each do |event|
        break if lookups >= DISCOVERY_LOOKUP_LIMIT

        headliner = event[:performers].first
        next if headliner.nil?
        norm = Concert.normalize_name(headliner[:name])
        next if known_names.include?(norm) || seen.include?(norm)
        seen << norm

        artist = ArtistResolver.resolve(headliner[:name])
        lookups += 1 if artist.updated_at > 5.seconds.ago

        next if artist.genres.blank?
        next if (artist.genres.to_set & top_genres).empty?
        save_event_performer(event, headliner)
      end
    end

    def save_event_performer(event, performer)
      upsert_concert(
        external_id: event[:id],
        title:       event[:title],
        artist_name: performer[:name],
        starts_on:   event[:date],
        venue_name:  event[:venue],
        venue_city:  event[:city],
        venue_country: event[:country] || "NL",
        url:         event[:url],
        image_url:   performer[:image] || event[:image],
        min_price:      event[:min_price],
        max_price:      event[:max_price],
        price_currency: event[:price_currency]
      )
    end

    def fetch_pages
      all = []
      MAX_PAGES.times do |i|
        page = i + 1
        html = fetch_html(page)
        break if html.blank?
        parsed = parse(html)
        break if parsed.empty?
        all.concat(parsed)
      end
      dedup(all)
    end

    def dedup(events)
      events.uniq { |e| e[:id] }
    end

    def fetch_html(page)
      response = HTTParty.get(BASE, query: (page > 1 ? { page: page } : {}),
        headers: { "User-Agent" => USER_AGENT, "Accept-Language" => "nl-NL,nl;q=0.9,en;q=0.8" },
        timeout: 15
      )
      response.success? ? response.body : ""
    rescue => e
      Rails.logger.warn("Podiuminfo fetch page #{page} failed: #{e.class} #{e.message}")
      ""
    end

    def parse(html)
      Nokogiri::HTML(html).css('script[type="application/ld+json"]').filter_map do |script|
        data = JSON.parse(script.text) rescue nil
        next unless data.is_a?(Hash) && data["@type"] == "MusicEvent"
        extract_event(data)
      end
    end

    def extract_event(data)
      url  = data["url"].to_s
      id   = url[%r{/concert/(\d+)}, 1]
      return nil if id.blank?

      start = data["startDate"].to_s
      date  = Date.parse(start) rescue nil
      return nil unless date

      location = data["location"] || {}
      country  = location.dig("address", "addressCountry")
      country  = "BE" if country.to_s.casecmp?("Belgium") || country.to_s.casecmp?("BE")
      country  = "NL" if country.blank? || country.to_s.casecmp?("Netherlands") || country.to_s.casecmp?("NL")

      performers = Array(data["performer"]).map do |p|
        {
          name:  p["name"].to_s.strip,
          image: p["image"].presence
        }
      end.reject { |p| p[:name].empty? }

      return nil if performers.empty?

      prices = Array(data["offers"]).filter_map { |o| o["price"]&.to_f }.reject(&:zero?)
      currency = Array(data["offers"]).find { |o| o["priceCurrency"].present? }&.[]("priceCurrency")

      {
        id:             "podiuminfo:#{id}",
        title:          data["name"],
        url:            url,
        date:           date,
        venue:          location["name"],
        city:           location.dig("address", "addressLocality"),
        country:        country,
        image:          data["image"].to_s.presence,
        performers:     performers,
        min_price:      prices.min,
        max_price:      prices.max,
        price_currency: currency
      }
    end
  end
end
