class AddArtistToConcerts < ActiveRecord::Migration[8.1]
  def change
    add_reference :concerts, :artist, foreign_key: true
  end
end
