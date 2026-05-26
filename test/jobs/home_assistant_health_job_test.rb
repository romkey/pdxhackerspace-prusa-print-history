require 'test_helper'

class HomeAssistantHealthJobTest < ActiveJob::TestCase
  setup do
    Setting.set(:ha_last_status, nil)
    Setting.set(:ha_last_error, nil)
  end

  test 'records not_configured when env vars are missing' do
    HomeAssistant::Client.stub(:from_env, HomeAssistant::Client.new(base_url: nil, token: nil)) do
      HomeAssistantHealthJob.perform_now
    end

    assert_equal 'not_configured', Setting.fetch(:ha_last_status)
    assert_match(/not set/, Setting.fetch(:ha_last_error))
    assert_not_nil Setting.fetch(:ha_last_polled_at)
  end

  test 'records ok when client.available? is true' do
    fake = Minitest::Mock.new
    fake.expect :configured?, true
    fake.expect :available?, true

    HomeAssistant::Client.stub(:from_env, fake) do
      HomeAssistantHealthJob.perform_now
    end

    assert_equal 'ok', Setting.fetch(:ha_last_status)
    assert_nil Setting.fetch(:ha_last_error)
    fake.verify
  end

  test 'records unreachable when client.available? is false' do
    fake = Minitest::Mock.new
    fake.expect :configured?, true
    fake.expect :available?, false

    HomeAssistant::Client.stub(:from_env, fake) do
      HomeAssistantHealthJob.perform_now
    end

    assert_equal 'unreachable', Setting.fetch(:ha_last_status)
    assert_match(/did not respond/, Setting.fetch(:ha_last_error))
    fake.verify
  end
end
