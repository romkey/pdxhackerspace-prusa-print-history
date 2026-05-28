class ConvertAmbientTempsFromFahrenheitToCelsius < ActiveRecord::Migration[8.1]
  # Values above this were stored as Fahrenheit from Home Assistant before unit conversion.
  FAHRENHEIT_THRESHOLD = 35

  def up
    convert_ambient_temps(:printers)
    convert_ambient_temps(:telemetry_readings)
  end

  def down
    revert_ambient_temps(:printers)
    revert_ambient_temps(:telemetry_readings)
  end

  private

  def convert_ambient_temps(table)
    say_with_time "Converting #{table}.ambient_temp from Fahrenheit to Celsius" do
      execute <<~SQL.squish
        UPDATE #{table}
        SET ambient_temp = ((ambient_temp - 32) * 5.0 / 9.0)
        WHERE ambient_temp IS NOT NULL AND ambient_temp > #{FAHRENHEIT_THRESHOLD}
      SQL
    end
  end

  def revert_ambient_temps(table)
    say_with_time "Reverting #{table}.ambient_temp from Celsius to Fahrenheit" do
      execute <<~SQL.squish
        UPDATE #{table}
        SET ambient_temp = (ambient_temp * 9.0 / 5.0) + 32
        WHERE ambient_temp IS NOT NULL AND ambient_temp > 2 AND ambient_temp < #{FAHRENHEIT_THRESHOLD}
      SQL
    end
  end
end
