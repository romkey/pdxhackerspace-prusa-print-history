class AddPrusaConnectToPrinters < ActiveRecord::Migration[8.1]
  def change
    change_table :printers, bulk: true do |t|
      t.text :prusa_connect_token
      t.string :prusa_connect_fingerprint
      t.datetime :prusa_connect_last_uploaded_at
    end
  end
end
