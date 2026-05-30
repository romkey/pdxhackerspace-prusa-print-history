require 'test_helper'
require Rails.root.join('db/migrate/20260527200000_convert_ambient_temps_from_fahrenheit_to_celsius')

class ConvertAmbientTempsFromFahrenheitToCelsiusTest < ActiveSupport::TestCase
  setup do
    @migration = ConvertAmbientTempsFromFahrenheitToCelsius.new
    @migration.verbose = false
    @printer = printers(:prusa_xl)
    @reading = telemetry_readings(:active_xl_one)
  end

  test 'converts ambient values that look like fahrenheit' do
    @printer.update!(ambient_temp: 72.0)
    @reading.update!(ambient_temp: 68.0)

    @migration.up

    assert_in_delta 22.222, @printer.reload.ambient_temp.to_f, 0.01
    assert_in_delta 20.0, @reading.reload.ambient_temp.to_f, 0.01
  end

  test 'leaves ambient values that are already celsius' do
    @printer.update!(ambient_temp: 21.5)
    @reading.update!(ambient_temp: 21.5)

    @migration.up

    assert_in_delta 21.5, @printer.reload.ambient_temp.to_f, 0.01
    assert_in_delta 21.5, @reading.reload.ambient_temp.to_f, 0.01
  end
end
