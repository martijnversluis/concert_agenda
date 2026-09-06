class CreateVenues < ActiveRecord::Migration[8.1]
  def change
    create_table :venues do |t|
      t.string :name
      t.string :city
      t.string :country
      t.string :url

      t.timestamps
    end
  end
end
