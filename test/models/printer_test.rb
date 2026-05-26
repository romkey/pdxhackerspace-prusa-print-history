require 'test_helper'

class PrinterTest < ActiveSupport::TestCase
  setup do
    @xl   = printers(:prusa_xl)
    @mini = printers(:prusa_mini)
  end

  test 'name is required and unique' do
    duplicate = Printer.new(name: @xl.name, hostname: 'other.local')

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], 'has already been taken'
  end

  test 'hostname is required' do
    printer = Printer.new(name: 'Brand New', hostname: nil)

    assert_not printer.valid?
    assert_includes printer.errors[:hostname], "can't be blank"
  end

  test 'derives Home Assistant enclosure and humidity sensor names' do
    assert_equal 'sensor.prusa_xl_monitor_bme680_temperature', @xl.enclosure_temp_sensor
    assert_equal 'sensor.prusa_xl_monitor_bme680_humidity',    @xl.humidity_sensor
  end

  test 'sensor helpers return nil when ha_base_sensor is blank' do
    assert_nil @mini.enclosure_temp_sensor
    assert_nil @mini.humidity_sensor
    assert_not @mini.home_assistant?
  end

  test 'camera? reflects camera_url presence' do
    assert_predicate @xl, :camera?
    assert_not @mini.camera?
  end

  test 'prusalink_key is encrypted at rest and round-trips in memory' do
    @xl.update!(prusalink_key: 'top-secret-key')

    raw = Printer.connection.select_value("SELECT prusalink_key FROM printers WHERE id = #{@xl.id}")

    assert_not_nil raw
    assert_not_equal 'top-secret-key', raw, 'value should be encrypted on disk'

    assert_equal 'top-secret-key', @xl.reload.prusalink_key
  end

  test 'prusalink? requires hostname and key' do
    @mini.prusalink_key = nil

    assert_not @mini.prusalink?

    @mini.prusalink_key = 'set'

    assert_predicate @mini, :prusalink?
  end
end
