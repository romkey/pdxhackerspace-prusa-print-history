require 'test_helper'

class SettingTest < ActiveSupport::TestCase
  test 'fetch returns the stored value' do
    assert_equal 'sensor.shop_ambient_temperature', Setting.fetch(:default_ambient_sensor)
  end

  test 'fetch returns the default when the key is missing' do
    assert_equal 'fallback', Setting.fetch(:ha_last_error, 'fallback')
    assert_nil Setting.fetch(:ha_last_error)
  end

  test 'set creates or updates the key' do
    Setting.set(:ha_last_status, 'ok')

    assert_equal 'ok', Setting.fetch(:ha_last_status)

    Setting.set(:ha_last_status, 'error')

    assert_equal 'error', Setting.fetch(:ha_last_status)
  end

  test 'set stores nil when value is nil' do
    Setting.set(:ha_last_error, 'something')
    Setting.set(:ha_last_error, nil)

    assert_nil Setting.fetch(:ha_last_error)
  end

  test 'unknown keys are rejected' do
    record = Setting.new(key: 'not_a_real_key', value: 'x')

    assert_not record.valid?
    assert_includes record.errors[:key], 'is not included in the list'
  end

  test 'default_ambient_sensor accessor strips blanks to nil' do
    Setting.default_ambient_sensor = '  '

    assert_nil Setting.default_ambient_sensor

    Setting.default_ambient_sensor = 'sensor.foo'

    assert_equal 'sensor.foo', Setting.default_ambient_sensor
  end

  test 'home_assistant_health returns a hash with parsed timestamp' do
    Setting.set(:ha_last_status, 'ok')
    Setting.set(:ha_last_polled_at, Time.zone.parse('2026-05-25 10:00:00').iso8601)

    health = Setting.home_assistant_health

    assert_equal 'ok', health[:status]
    assert_kind_of Time, health[:polled_at]
    assert_nil health[:error]
  end
end
