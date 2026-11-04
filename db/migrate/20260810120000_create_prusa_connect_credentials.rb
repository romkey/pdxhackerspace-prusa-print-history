class CreatePrusaConnectCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :prusa_connect_credentials do |t|
      t.text :refresh_token
      t.text :access_token
      t.datetime :access_token_expires_at
      t.datetime :last_synced_at
      t.text :last_error

      t.timestamps
    end
  end
end
