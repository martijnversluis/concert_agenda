module Adapters
  class Ticketmaster < BaseAdapter
    BASE_URL = "https://app.ticketmaster.com/discovery/v2".freeze

    def self.enabled?
      ENV["TICKETMASTER_API_KEY"].present?
    end

    def fetch_for(artist_name)
      return [] unless self.class.enabled?

      response = HTTParty.get("#{BASE_URL}/events.json", query: {
        apikey: ENV["TICKETMASTER_API_KEY"],
        keyword: artist_name,
        countryCode: "NL",
        classificationName: "Music",
        size: 50,
        sort: "date,asc",
        endDateTime: "#{Concert.agenda_end_date}T23:59:59Z"
      })

      return [] unless response.success?

      events = response.dig("_embedded", "events") || []
      events.filter_map { |event| build_from_event(event, artist_name) }
    rescue => e
      Rails.logger.warn("Ticketmaster fetch failed for #{artist_name}: #{e.class} #{e.message}")
      []
    end

    private

    def build_from_event(event, requested_artist_name)
      matched_artist = pick_matching_attraction(event, requested_artist_name)
      return nil unless matched_artist

      venue = event.dig("_embedded", "venues")&.first || {}
      dates = event["dates"] || {}
      start = dates["start"] || {}

      starts_on = Date.parse(start["localDate"]) if start["localDate"]
      return nil unless starts_on

      starts_at = begin
        Time.zone.parse("#{start["localDate"]} #{start["localTime"]}") if start["localTime"]
      rescue
        nil
      end

      image = (event["images"] || []).max_by { |i| i["width"].to_i }&.dig("url")

      standard = (event["priceRanges"] || []).find { |pr| pr["type"] == "standard" } || (event["priceRanges"] || []).first

      upsert_concert(
        external_id: event["id"],
        title:       event["name"],
        artist_name: matched_artist,
        starts_on:   starts_on,
        starts_at:   starts_at,
        venue_name:  venue["name"],
        venue_city:  venue.dig("city", "name"),
        venue_country: venue.dig("country", "countryCode") || "NL",
        url:         event["url"],
        image_url:   image,
        min_price:      standard&.dig("min"),
        max_price:      standard&.dig("max"),
        price_currency: standard&.dig("currency")
      )
    end

    # Only return the artist name if the event actually credits an attraction
    # matching (case-insensitive) the artist we searched for. Prevents "keyword"
    # noise: venue mentions, tribute bands, etc.
    def pick_matching_attraction(event, requested_artist_name)
      needle = Concert.normalize_name(requested_artist_name)
      attractions = event.dig("_embedded", "attractions") || []

      match = attractions.find { |a| Concert.normalize_name(a["name"]) == needle }
      match && match["name"]
    end
  end
end
