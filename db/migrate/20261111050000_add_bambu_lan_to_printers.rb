class AddBambuLanToPrinters < ActiveRecord::Migration[8.1]
  def change
    add_column :printers, :printer_type, :string, null: false, default: 'prusa'
    add_column :printers, :bambu_serial, :string
    add_column :printers, :bambu_access_code, :text
  end
end
