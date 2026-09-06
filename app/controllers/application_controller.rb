class ApplicationController < ActionController::Base
  include ConcertSyncing

  allow_browser versions: :modern
  stale_when_importmap_changes

  helper_method :current_user, :signed_in?, :syncing?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def signed_in?
    current_user.present?
  end
end
