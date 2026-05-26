require 'test_helper'

class TimezoneTest < ActiveSupport::TestCase
  test 'defaults to UTC when TIMEZONE is unset' do
    assert_equal 'UTC', Time.zone.name
  end

  test 'formats times in the configured zone' do
    time = Time.utc(2026, 5, 25, 18, 30, 0)
    formatted = I18n.l(time.in_time_zone, format: :short)

    assert_includes formatted, '18:30'
  end
end
