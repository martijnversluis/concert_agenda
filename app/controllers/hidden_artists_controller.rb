class HiddenArtistsController < ApplicationController
  before_action :require_login

  def create
    @hidden_artist = current_user.hidden_artists.find_or_create_by!(
      spotify_artist_id: params.require(:spotify_artist_id)
    ) do |ha|
      ha.name      = params[:name]
      ha.image_url = params[:image_url]
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  def destroy
    current_user.hidden_artists.find(params[:id]).destroy
    redirect_back fallback_location: root_path
  end

  private

  def require_login
    redirect_to root_path unless signed_in?
  end
end
