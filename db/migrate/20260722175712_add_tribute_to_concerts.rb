class AddTributeToConcerts < ActiveRecord::Migration[8.1]
  def change
    add_column :concerts, :tribute, :boolean
    add_column :concerts, :cover_band_name, :string
  end
end
