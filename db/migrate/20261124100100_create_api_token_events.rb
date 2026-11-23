class CreateApiTokenEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :api_token_events do |t|
      t.references :api_token, index: false, foreign_key: { on_delete: :nullify }
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :subject, polymorphic: true
      t.string :action, null: false
      t.string :ip
      t.jsonb :detail, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :api_token_events, %i[api_token_id occurred_at]
    add_index :api_token_events, :occurred_at
  end
end
