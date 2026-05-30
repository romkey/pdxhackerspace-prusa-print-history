class CreatePrinterEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :printer_events do |t|
      t.references :printer, null: false, foreign_key: true

      t.string   :event_type, null: false
      t.integer  :tool_index
      t.string   :from_material
      t.string   :to_material
      t.text     :message
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :printer_events, :occurred_at
    add_index :printer_events, %i[printer_id occurred_at]
  end
end
