class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :spotify_id
      t.string :display_name
      t.string :email
      t.string :image_url
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at

      t.timestamps
    end
    add_index :users, :spotify_id, unique: true
  end
end
