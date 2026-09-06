class HomeController < ApplicationController
  ConcertRow = Struct.new(:concert, :tip, :overlap, :similar_to, keyword_init: true)

  def index
    return unless signed_in?

    ensure_concert_sync!

    user_concerts = deduplicate(
      Concert.for_user(current_user).upcoming.includes(:venue, :artist).to_a
    )

    tips = ConcertRecommender.new(current_user).recommendations

    rows = build_rows(user_concerts, tips)
    @rows_by_month = rows.group_by { |r| r.concert.starts_on.beginning_of_month }
  end

  private

  def build_rows(user_concerts, tips)
    seen_keys = user_concerts.map { |c| [c.artist_name_normalized, c.starts_on] }.to_set

    tip_rows = tips.filter_map do |tip|
      next if seen_keys.include?([tip.concert.artist_name_normalized, tip.concert.starts_on])
      ConcertRow.new(concert: tip.concert, tip: true, overlap: tip.overlap, similar_to: tip.similar_to)
    end

    rows = user_concerts.map { |c| ConcertRow.new(concert: c, tip: false, overlap: [], similar_to: []) } + tip_rows

    dedupe_by_venue_and_date(rows).sort_by { |r| r.concert.starts_on }
  end

  # Same venue + date across a "real" row and a tip row → the real row wins.
  # This catches tribute events where multiple bands from the same event slip
  # into different buckets.
  def dedupe_by_venue_and_date(rows)
    rows.group_by { |r| [r.concert.venue_id, r.concert.starts_on] }.flat_map do |(venue_id, _), group|
      next group if group.size == 1 || venue_id.nil?
      [group.min_by { |r| [r.tip ? 1 : 0, -r.concert.cover_band_name.to_s.length] }]
    end
  end

  # Step 1: Ticketmaster VIP/lounge packages get separate event ids with venue
  # variants ("Ziggo Dome Club"). Step 2: festival umbrella listings from
  # festivalinfo/podiuminfo overlap with per-day listings from metalagenda — same
  # artist, same city, dates within a few days. Prefer the specific per-day one.
  def deduplicate(concerts)
    per_date = concerts
      .group_by { |c| [c.artist_name_normalized, c.starts_on] }
      .values
      .map { |group| group.min_by { |c| [venue_penalty(c), c.venue&.name.to_s.length] } }

    collapse_tribute_duplicates(collapse_festival_neighbours(per_date))
      .sort_by(&:starts_on)
  end

  # A tribute event where the user follows BOTH the cover band and the covered
  # artist ends up saved twice by the same source. Same venue + date + tribute
  # → keep the one with cover_band_name populated (it renders more clearly).
  def collapse_tribute_duplicates(concerts)
    concerts.group_by { |c| [c.venue_id, c.starts_on, c.tribute?] }.flat_map do |(_, _, tribute), group|
      next group unless tribute && group.size > 1
      [group.max_by { |c| c.cover_band_name.to_s.length }]
    end
  end

  def collapse_festival_neighbours(concerts)
    concerts.sort_by(&:starts_on).each_with_object([]) do |concert, acc|
      neighbour = acc.find do |other|
        other.artist_name_normalized == concert.artist_name_normalized &&
          other.venue&.city.to_s.downcase == concert.venue&.city.to_s.downcase &&
          other.venue&.city.present? &&
          (other.starts_on - concert.starts_on).abs <= 7
      end

      if neighbour
        if festival_venue?(neighbour) && !festival_venue?(concert)
          acc[acc.index(neighbour)] = concert
        end
      else
        acc << concert
      end
    end
  end

  def festival_venue?(concert)
    concert.venue&.name.to_s.match?(/\b(fest|festival)\b/i)
  end

  def venue_penalty(concert)
    name = concert.venue&.name.to_s.downcase
    return 1 if name.match?(/\b(club|lounge|loge|premium|vip|hospitality|balcony|business)\b/)
    0
  end
end
