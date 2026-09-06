module Adapters
  class BaseAdapter
    def self.source_name
      name.demodulize.underscore
    end

    def self.enabled?
      true
    end

    # Default: per-artist fetch (Ticketmaster style).
    # Override for adapters that scrape once and match afterwards (Metalagenda).
    def run_for_user(user, artists)
      artists.find_each do |artist|
        fetch_for(artist.name)
      end
    end

    def fetch_for(artist_name)
      raise NotImplementedError, "override fetch_for or run_for_user"
    end

    protected

    def upsert_concert(external_id:, title:, artist_name:, starts_on:, starts_at: nil,
                      venue_name: nil, venue_city: nil, venue_country: "NL",
                      url: nil, image_url: nil, tribute: false, cover_band_name: nil,
                      min_price: nil, max_price: nil, price_currency: nil)
      venue = if venue_name.present?
                Venue.find_or_create_by!(name: venue_name, city: venue_city, country: venue_country)
              end

      artist = ArtistResolver.resolve(artist_name)

      # For tributes we don't want the *original* band's photo (misleading).
      # Try to resolve the cover band; if we can't, drop the image entirely.
      display_image =
        if tribute
          cover_band_name.present? ? ArtistResolver.resolve(cover_band_name)&.image_url : nil
        else
          image_url.presence || artist&.image_url
        end

      concert = Concert.find_or_initialize_by(source: self.class.source_name, external_id: external_id)
      concert.assign_attributes(
        title: title,
        artist_name: artist_name,
        artist_name_normalized: Concert.normalize_name(artist_name),
        starts_on: starts_on,
        starts_at: starts_at,
        venue_id: venue&.id,
        artist_id: artist&.id,
        url: url,
        image_url: display_image,
        tribute: tribute,
        cover_band_name: cover_band_name,
        min_price: min_price,
        max_price: max_price,
        price_currency: price_currency
      )
      concert.save!
      concert
    end
  end
end
