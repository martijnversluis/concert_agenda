class CreateHiddenArtists < ActiveRecord::Migration[8.1]
  def change
    create_table :hidden_artists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :spotify_artist_id, null: false
      t.string :name
      t.string :image_url

      t.timestamps
    end

    add_index :hidden_artists, [:user_id, :spotify_artist_id], unique: true
  end
end
