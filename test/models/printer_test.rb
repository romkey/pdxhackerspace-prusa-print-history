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

  test 'prusa_connect_token is encrypted at rest and round-trips in memory' do
    @xl.update!(prusa_connect_token: 'connect-camera-token')

    raw = Printer.connection.select_value("SELECT prusa_connect_token FROM printers WHERE id = #{@xl.id}")

    assert_not_nil raw
    assert_not_equal 'connect-camera-token', raw, 'value should be encrypted on disk'

    assert_equal 'connect-camera-token', @xl.reload.prusa_connect_token
  end

  test 'prusa_connect? requires token and fingerprint' do
    assert_not @mini.prusa_connect?

    @mini.update!(prusa_connect_token: 'camera-token-12345678')

    assert_predicate @mini, :prusa_connect?
    assert_equal 32, @mini.prusa_connect_fingerprint.length
  end

  test 'prusa_connect fingerprint persists across token updates' do
    @mini.update!(prusa_connect_token: 'first-token-1234567890')
    original = @mini.prusa_connect_fingerprint

    @mini.update!(prusa_connect_token: 'second-token-123456789')

    assert_equal original, @mini.reload.prusa_connect_fingerprint
  end

  test 'prusalink? requires hostname and key' do
    @mini.prusalink_key = nil

    assert_not @mini.prusalink?

    @mini.prusalink_key = 'set'

    assert_predicate @mini, :prusalink?
  end

  test 'display_status prefers active job over stale idle operational_state' do
    @xl.update!(operational_state: 'idle')

    assert @xl.current_job.present?
    assert_equal 'printing', @xl.display_status
    assert_not @xl.idle?
  end

  test 'display_status uses operational_state when no active job' do
    @xl.update!(operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)

    assert_equal 'idle', @xl.display_status
    assert_predicate @xl, :idle?
  end

  test 'display_status falls back to current job when operational_state is unknown' do
    assert_equal 'printing', @xl.display_status
  end

  test 'display_status is idle when no active job and state is unknown' do
    @mini.update!(operational_state: 'unknown')

    assert_equal 'idle', @mini.display_status
  end

  test 'display_status falls back to current job when environment columns are absent' do
    without_environment_columns do
      assert_not @xl.environment_tracking?
      assert_equal 'printing', @xl.display_status
    end
  end

  test 'prusalink_connection_status reflects reachability' do
    @xl.update!(prusalink_key: 'secret', prusalink_reachable: true)

    assert_equal :reachable, @xl.prusalink_connection_status

    @xl.update!(prusalink_reachable: false)

    assert_equal :unreachable, @xl.prusalink_connection_status
  end

  test 'prusalink_connection_status is unconfigured without a key' do
    @mini.update!(prusalink_key: nil)

    assert_equal :unconfigured, @mini.prusalink_connection_status
  end

  private

  def without_environment_columns(&)
    columns = Printer.column_names - Printer::ENVIRONMENT_COLUMNS - Printer::CONNECTIVITY_COLUMNS
    Printer.stub(:column_names, columns, &)
  end
end
