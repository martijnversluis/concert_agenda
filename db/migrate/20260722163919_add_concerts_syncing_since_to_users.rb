class AddConcertsSyncingSinceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :concerts_syncing_since, :datetime
  end
end
