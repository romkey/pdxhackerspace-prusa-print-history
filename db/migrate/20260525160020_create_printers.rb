class CreatePrinters < ActiveRecord::Migration[8.1]
  def change
    create_table :printers do |t|
      t.string :name,     null: false
      t.string :location
      t.string :model
      t.string :hostname, null: false
      t.text   :prusalink_key
      t.string :ha_base_sensor
      t.string :camera_url

      t.timestamps
    end

    add_index :printers, :name, unique: true
  end
end
