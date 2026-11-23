class AddFirmwareComponentsToPrinters < ActiveRecord::Migration[8.1]
  def change
    add_column :printers, :firmware_components, :jsonb, default: {}, null: false
  end
end
