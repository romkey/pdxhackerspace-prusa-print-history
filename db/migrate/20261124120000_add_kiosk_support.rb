class AddKioskSupport < ActiveRecord::Migration[8.1]
  def change
    # Stable Authentik identifier from the member_id claim. Encrypted deterministically so it
    # can be looked up; text because ciphertext is longer than the value.
    add_column :users, :member_id, :text
    add_index :users, :member_id, unique: true

    add_reference :api_tokens, :parent_token, foreign_key: { to_table: :api_tokens, on_delete: :cascade }
    add_column :api_tokens, :can_display_login_links, :boolean, null: false, default: false
    add_index :api_tokens, %i[kind expires_at]
  end
end
