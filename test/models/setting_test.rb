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

  test 'dashboard and footer accessors strip blanks to nil' do
    Setting.dashboard_heading = '  '
    Setting.footer_text = '  '
    Setting.footer_link_label = '  '
    Setting.footer_link_url = '  '

    assert_nil Setting.dashboard_heading
    assert_nil Setting.footer_text
    assert_nil Setting.footer_link_label
    assert_nil Setting.footer_link_url

    Setting.dashboard_heading = 'Shop printers'
    Setting.footer_text = 'PDX Hackerspace 3D Printing'
    Setting.footer_link_label = 'FAQ'
    Setting.footer_link_url = 'https://example.com/faq'

    assert_equal 'Shop printers', Setting.dashboard_heading
    assert_equal 'PDX Hackerspace 3D Printing', Setting.footer_text
    assert_equal 'FAQ', Setting.footer_link_label
    assert_equal 'https://example.com/faq', Setting.footer_link_url
  end

  test 'prusa training messages default when unset and can be cleared' do
    assert_equal Setting::DEFAULT_PRUSA_UNTRAINED_MESSAGE, Setting.prusa_untrained_message
    assert_equal Setting::DEFAULT_PRUSA_TRAINED_ACCOUNT_MESSAGE, Setting.prusa_trained_account_message

    Setting.prusa_untrained_message = 'Custom untrained.'
    Setting.prusa_trained_account_message = 'Custom account.'

    assert_equal 'Custom untrained.', Setting.prusa_untrained_message
    assert_equal 'Custom account.', Setting.prusa_trained_account_message

    Setting.prusa_trained_account_message = '   '

    assert_nil Setting.prusa_trained_account_message
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
