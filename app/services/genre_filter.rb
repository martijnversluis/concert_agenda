module GenreFilter
  STOPWORDS = %w[
    dutch american british german swedish norwegian finnish japanese
    australian canadian french spanish italian belgian scottish irish
    greek polish russian mexican chilean brazilian
    netherlands usa uk germany sweden norway finland japan
    australia canada france spain italy belgium
    english
    80s 90s 00s 10s 20s
    seen\ live favorites favourites favorite awesome cool amazing best
    live music radio band artist artists solo group
    male\ vocalists female\ vocalists singer-songwriter
    ai\ slop urban
  ].map(&:downcase).to_set.freeze

  def self.clean(tags)
    tags.filter_map do |t|
      s = t.to_s.strip.downcase
      next if s.empty?
      next if STOPWORDS.include?(s)
      next if s.match?(/\A\d{2,4}s\z/)
      s
    end.uniq
  end
end
