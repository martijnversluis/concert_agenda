class SessionsController < ApplicationController
  def create
    user = User.from_omniauth(request.env["omniauth.auth"])
    session[:user_id] = user.id
    redirect_to root_path, notice: "Ingelogd als #{user.display_name}"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Uitgelogd"
  end

  def failure
    redirect_to root_path, alert: "Inloggen mislukt: #{params[:message]}"
  end
end
