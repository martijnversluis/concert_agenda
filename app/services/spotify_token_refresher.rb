class SpotifyTokenRefresher
  TOKEN_URL = "https://accounts.spotify.com/api/token".freeze
  REFRESH_MARGIN = 60.seconds

  def initialize(user)
    @user = user
  end

  def ensure_fresh!
    return if @user.access_token.present? &&
              @user.token_expires_at.present? &&
              @user.token_expires_at > (Time.current + REFRESH_MARGIN)

    refresh!
  end

  private

  def refresh!
    response = HTTParty.post(TOKEN_URL,
      headers: {
        "Authorization" => "Basic #{basic_auth}",
        "Content-Type"  => "application/x-www-form-urlencoded"
      },
      body: {
        grant_type: "refresh_token",
        refresh_token: @user.refresh_token
      }
    )

    unless response.success?
      raise "Spotify token refresh failed: #{response.code} #{response.body}"
    end

    @user.update!(
      access_token:    response["access_token"],
      refresh_token:   response["refresh_token"].presence || @user.refresh_token,
      token_expires_at: Time.current + response["expires_in"].to_i.seconds
    )
  end

  def basic_auth
    Base64.strict_encode64("#{ENV["SPOTIFY_CLIENT_ID"]}:#{ENV["SPOTIFY_CLIENT_SECRET"]}")
  end
end
