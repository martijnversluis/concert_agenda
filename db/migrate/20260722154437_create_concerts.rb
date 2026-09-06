class CreateConcerts < ActiveRecord::Migration[8.1]
  def change
    create_table :concerts do |t|
      t.string   :source, null: false
      t.string   :external_id, null: false
      t.string   :title
      t.string   :artist_name
      t.string   :artist_name_normalized
      t.datetime :starts_at
      t.date     :starts_on
      t.references :venue, foreign_key: true
      t.string   :url
      t.string   :image_url

      t.timestamps
    end

    add_index :concerts, [:source, :external_id], unique: true
    add_index :concerts, :starts_on
    add_index :concerts, :artist_name_normalized
  end
end
