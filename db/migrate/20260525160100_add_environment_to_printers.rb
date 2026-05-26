class AddEnvironmentToPrinters < ActiveRecord::Migration[8.1]
  def change
    change_table :printers, bulk: true do |t|
      t.string :operational_state, null: false, default: 'unknown'
      t.decimal :ambient_temp, precision: 6, scale: 2
      t.decimal :enclosure_temp, precision: 6, scale: 2
      t.decimal :enclosure_humidity, precision: 6, scale: 2
      t.datetime :environment_updated_at
    end
  end
end
