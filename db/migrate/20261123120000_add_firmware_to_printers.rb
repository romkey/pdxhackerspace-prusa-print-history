class AddFirmwareToPrinters < ActiveRecord::Migration[8.1]
  def change
    add_column :printers, :firmware_version, :string
    add_column :printers, :firmware_checked_at, :datetime
  end
end
