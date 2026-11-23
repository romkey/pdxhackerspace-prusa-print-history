class CreateLoginLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :login_links do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :requested_by_token, foreign_key: { to_table: :api_tokens, on_delete: :nullify }
      t.string :token_digest, null: false
      t.string :return_to, null: false, default: '/'
      t.string :delivery, null: false, default: 'email'
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :login_links, :token_digest, unique: true
    add_index :login_links, %i[user_id created_at]
    add_index :login_links, :expires_at
  end
end
