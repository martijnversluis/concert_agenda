class AddManualToTopArtists < ActiveRecord::Migration[8.1]
  def change
    add_column :top_artists, :manual, :boolean, default: false, null: false
  end
end
