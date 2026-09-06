require "rspotify"

Rails.application.config.after_initialize do
  if ENV["SPOTIFY_CLIENT_ID"].present? && ENV["SPOTIFY_CLIENT_SECRET"].present?
    RSpotify.authenticate(ENV["SPOTIFY_CLIENT_ID"], ENV["SPOTIFY_CLIENT_SECRET"])
  end
end
