class SpotifyArtistsController < ApplicationController
  before_action :require_login

  def top_tracks
    artist = SpotifyThrottle.call { RSpotify::Artist.find(params[:spotify_id]) }
    @artist_id = params[:spotify_id]
    @tracks = SpotifyThrottle.call { artist.top_tracks(:NL) }.first(5)
    render layout: false
  rescue RestClient::ResourceNotFound
    head :not_found
  end

  private

  def require_login
    redirect_to root_path unless signed_in?
  end
end
