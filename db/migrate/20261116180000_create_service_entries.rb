class CreateServiceEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :service_entries do |t|
      t.references :printer, null: false, foreign_key: true
      t.references :user, foreign_key: { on_delete: :nullify }
      t.references :resolved_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :resolving_repair, foreign_key: { to_table: :service_entries, on_delete: :nullify }

      t.string :kind, null: false
      t.string :summary, null: false
      t.text :details
      t.datetime :occurred_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :service_entries, :occurred_at
    add_index :service_entries, %i[printer_id occurred_at]
    add_index :service_entries, %i[kind occurred_at]
    add_index :service_entries, :printer_id,
              where: "kind = 'problem' AND resolved_at IS NULL",
              name: 'index_service_entries_on_open_problems'

    add_column :printers, :out_of_service_since, :datetime
    add_index :printers, :out_of_service_since,
              where: 'out_of_service_since IS NOT NULL',
              name: 'index_printers_on_out_of_service_since'
  end
end
