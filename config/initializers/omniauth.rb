Rails.application.config.middleware.use OmniAuth::Builder do
  provider :spotify,
           ENV["SPOTIFY_CLIENT_ID"],
           ENV["SPOTIFY_CLIENT_SECRET"],
           scope: "user-read-email user-top-read user-follow-read"
end

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true
