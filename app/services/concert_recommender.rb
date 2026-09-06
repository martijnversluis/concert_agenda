class ConcertRecommender
  Recommendation = Struct.new(:concert, :overlap, :similar_to, keyword_init: true)

  MIN_SHARED_GENRES  = 1
  TOP_GENRE_COUNT    = 15
  MAX_RECOMMENDATIONS = 40
  SIMILAR_TO_COUNT   = 2

  def initialize(user)
    @user = user
  end

  def recommendations
    hidden_ids  = @user.hidden_artists.pluck(:spotify_artist_id).to_set
    tops        = visible_top_artists(hidden_ids)
    tops_by_name = tops.index_by(&:name_normalized)
    known_names = tops.map(&:name_normalized).to_set

    Concert.upcoming
      .includes(:venue, :artist)
      .where.not(artist_id: nil)
      .where.not(artist_name_normalized: known_names.to_a)
      .reject { |c| c.artist.spotify_id && hidden_ids.include?(c.artist.spotify_id) }
      .filter_map do |concert|
        similar = similar_top_artists(concert.artist, tops_by_name)
        overlap = genre_overlap(concert.artist)

        next if similar.empty? && overlap.size < MIN_SHARED_GENRES

        Recommendation.new(
          concert: concert,
          overlap: overlap.to_a,
          similar_to: similar.presence || fallback_similar(concert.artist, tops)
        )
      end
      .sort_by { |r| [-r.similar_to.size, -r.overlap.size, r.concert.starts_on] }
      .first(MAX_RECOMMENDATIONS)
  end

  def user_top_genres
    @user_top_genres ||= begin
      hidden_ids = @user.hidden_artists.pluck(:spotify_artist_id).to_set
      counts = Hash.new(0)
      visible_top_artists(hidden_ids).each do |artist|
        GenreFilter.clean(Array(artist.genres)).each { |g| counts[g] += 1 }
      end
      counts.sort_by { |_, c| -c }.first(TOP_GENRE_COUNT).map(&:first).to_set
    end
  end

  private

  def visible_top_artists(hidden_ids)
    @user.top_artists.reject { |a| hidden_ids.include?(a.spotify_id) }
  end

  def similar_top_artists(artist, tops_by_name)
    similar_names = Array(artist.similar_artist_names)
    return [] if similar_names.empty?

    matched = similar_names.filter_map { |n| tops_by_name[n] }
    matched.sort_by { |top| top.best_rank || 999 }.first(SIMILAR_TO_COUNT)
  end

  def fallback_similar(artist, tops)
    artist_genres = Array(artist.genres).to_set
    return [] if artist_genres.empty?

    tops
      .filter_map do |top|
        shared = artist_genres & Array(top.genres).to_set
        next if shared.empty?
        [top, shared.size]
      end
      .sort_by { |top, count| [-count, top.best_rank || 999] }
      .first(SIMILAR_TO_COUNT)
      .map(&:first)
  end

  def genre_overlap(artist)
    return Set.new if artist.blank? || artist.genres.blank?
    Array(artist.genres).to_set & user_top_genres
  end
end
