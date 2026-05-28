class CreateLabelPrinters < ActiveRecord::Migration[8.1]
  def change
    create_table :label_printers do |t|
      t.string :name, null: false
      t.string :cups_printer_name, null: false
      t.string :cups_printer_server
      t.boolean :default_printer, default: false, null: false
      t.integer :position, default: 0, null: false
      t.integer :thermal_roll_width_mm
      t.string :description
      t.string :health_status, default: 'unknown', null: false
      t.datetime :last_health_check_at
      t.string :last_health_error

      t.timestamps
    end

    add_index :label_printers, :name, unique: true
    add_index :label_printers, %i[cups_printer_name cups_printer_server], unique: true
  end
end
