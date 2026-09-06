class AddGenresToTopArtists < ActiveRecord::Migration[8.1]
  def change
    add_column :top_artists, :genres, :json
  end
end
