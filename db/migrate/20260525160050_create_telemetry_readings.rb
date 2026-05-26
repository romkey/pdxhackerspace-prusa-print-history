class CreateTelemetryReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :telemetry_readings do |t|
      t.references :job, null: false, foreign_key: true

      t.datetime :recorded_at, null: false
      t.jsonb    :tool_temps,  null: false, default: {}
      t.decimal  :bed_temp,           precision: 6, scale: 2
      t.decimal  :enclosure_temp,     precision: 6, scale: 2
      t.decimal  :ambient_temp,       precision: 6, scale: 2
      t.decimal  :enclosure_humidity, precision: 6, scale: 2

      t.timestamps
    end

    add_index :telemetry_readings, %i[job_id recorded_at]
  end
end
