class AddSimilarArtistNamesToArtists < ActiveRecord::Migration[8.1]
  def change
    add_column :artists, :similar_artist_names, :json
  end
end
