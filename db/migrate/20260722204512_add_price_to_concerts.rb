class AddPriceToConcerts < ActiveRecord::Migration[8.1]
  def change
    add_column :concerts, :min_price,      :decimal, precision: 10, scale: 2
    add_column :concerts, :max_price,      :decimal, precision: 10, scale: 2
    add_column :concerts, :price_currency, :string,  limit: 3
  end
end
