Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # OAuth
  post "/auth/spotify", as: :spotify_login
  get  "/auth/spotify/callback", to: "sessions#create"
  get  "/auth/failure",          to: "sessions#failure"
  delete "/logout",              to: "sessions#destroy", as: :logout

  resources :hidden_artists, only: [:create, :destroy]

  resources :artists, only: [:index, :create, :destroy] do
    collection { get :search }
  end

  get "/spotify/artists/:spotify_id/top_tracks",
      to: "spotify_artists#top_tracks",
      as: :spotify_artist_top_tracks

  root "home#index"
end
