class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :name, null: false
      t.string :kind, null: false, default: 'personal'
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.string :access_level, null: false, default: 'read'
      t.datetime :expires_at
      t.datetime :paused_at
      t.datetime :revoked_at
      t.string :allowed_cidrs, array: true, null: false, default: []
      t.datetime :last_used_at
      t.string :last_used_ip
      t.timestamps
    end

    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, :kind
  end
end
