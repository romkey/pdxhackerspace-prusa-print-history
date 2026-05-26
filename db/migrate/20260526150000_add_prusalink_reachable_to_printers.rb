class AddPrusalinkReachableToPrinters < ActiveRecord::Migration[8.1]
  def change
    change_table :printers, bulk: true do |t|
      t.boolean :prusalink_reachable
      t.datetime :prusalink_checked_at
    end
  end
end
