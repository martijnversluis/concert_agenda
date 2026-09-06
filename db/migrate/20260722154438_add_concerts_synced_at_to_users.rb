class AddConcertsSyncedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :concerts_synced_at, :datetime
  end
end
