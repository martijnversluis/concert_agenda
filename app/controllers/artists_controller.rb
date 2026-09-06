class ArtistsController < ApplicationController
  before_action :require_login

  def index
    ensure_concert_sync!

    hidden_ids = current_user.hidden_artists.pluck(:spotify_artist_id).to_set
    @top_artists = current_user.top_artists.order(:best_rank, :name)
                     .reject { |a| hidden_ids.include?(a.spotify_id) }
    @hidden_artists = current_user.hidden_artists.order(:name)
  end

  def create
    name = params.require(:name).to_s.strip
    if name.blank?
      redirect_to artists_path, alert: "Geef een naam op." and return
    end

    top_artist = ManualArtistAdder.new(current_user).add(name)
    if top_artist.persisted?
      FetchConcertsForUserJob.perform_later(current_user.id)
      msg = if top_artist.name_normalized.start_with?("spotify:")
              "Artiest toegevoegd. Naam wordt aangevuld zodra Spotify weer bereikbaar is."
            else
              "#{top_artist.name} toegevoegd. Concerten worden opgehaald."
            end
      redirect_to artists_path, notice: msg
    else
      redirect_to artists_path, alert: top_artist.errors.full_messages.to_sentence
    end
  end

  def search
    q = params[:q].to_s.strip
    render json: { results: [] } and return if q.length < 2

    results = SpotifyThrottle.call { RSpotify::Artist.search(q, limit: 8) }.map do |a|
      {
        spotify_id: a.id,
        name:       a.name,
        image_url:  a.images&.min_by { |i| i["width"].to_i }&.dig("url"),
        genres:     Array(a.genres).first(2)
      }
    end
    render json: { results: results }
  rescue SpotifyThrottle::CoolingDown => e
    render json: { results: [], error: "Spotify rate-limited (nog #{e.retry_after.round}s)" }
  rescue => e
    Rails.logger.warn("Artists#search failed: #{e.class} #{e.message}")
    render json: { results: [], error: e.class.to_s.demodulize }
  end

  def destroy
    ta = current_user.top_artists.find(params[:id])
    if ta.manual?
      ta.destroy
      redirect_to artists_path, notice: "#{ta.name} verwijderd."
    else
      redirect_to artists_path, alert: "Alleen handmatig toegevoegde artiesten kun je zo verwijderen. Gebruik 'Verberg' voor de rest."
    end
  end

  private

  def require_login
    redirect_to root_path unless signed_in?
  end
end
