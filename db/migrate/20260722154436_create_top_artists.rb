class CreateTopArtists < ActiveRecord::Migration[8.1]
  def change
    create_table :top_artists do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :spotify_id, null: false
      t.string  :name, null: false
      t.string  :name_normalized, null: false
      t.string  :image_url
      t.integer :best_rank

      t.timestamps
    end

    add_index :top_artists, [:user_id, :spotify_id], unique: true
    add_index :top_artists, :name_normalized
  end
end
