class Concert < ApplicationRecord
  belongs_to :venue, optional: true
  belongs_to :artist, optional: true

  # Cap agenda at end of next March (rolling window).
  def self.agenda_end_date
    year = Date.current.year + (Date.current.month > 3 ? 1 : 0)
    Date.new(year, 3, 31)
  end

  scope :upcoming, -> {
    where(starts_on: Date.current..agenda_end_date).order(:starts_on)
  }

  def self.for_user(user)
    hidden_ids = user.hidden_artists.pluck(:spotify_artist_id)
    names = user.top_artists.where.not(spotify_id: hidden_ids).pluck(:name_normalized)
    return none if names.empty?
    where(artist_name_normalized: names)
  end

  def price_display
    return nil if min_price.blank? && max_price.blank?

    symbol = price_currency == "EUR" ? "€" : (price_currency || "")
    if min_price.present? && max_price.present? && min_price != max_price
      "#{symbol} #{format_amount(min_price)}–#{format_amount(max_price)}"
    else
      "#{symbol} #{format_amount(min_price || max_price)}"
    end
  end

  private

  def format_amount(n)
    n.to_d.to_i == n.to_d ? n.to_i.to_s : format("%.2f", n)
  end

  public

  def self.normalize_name(name)
    return "" if name.blank?
    name.to_s.strip.downcase.unicode_normalize(:nfkd).gsub(/\p{Mn}+/, "").squeeze(" ")
  end
end
