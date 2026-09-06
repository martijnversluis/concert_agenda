class CreateArtists < ActiveRecord::Migration[8.1]
  def change
    create_table :artists do |t|
      t.string :spotify_id
      t.string :name, null: false
      t.string :name_normalized, null: false
      t.string :image_url
      t.json   :genres, default: []
      t.datetime :spotify_looked_up_at

      t.timestamps
    end
    add_index :artists, :spotify_id, unique: true
    add_index :artists, :name_normalized
  end
end
