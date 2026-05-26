class HomeAssistantHealthJob < ApplicationJob
  queue_as :default

  def perform
    client = HomeAssistant::Client.from_env

    unless client.configured?
      Setting.set(:ha_last_status, 'not_configured')
      Setting.set(:ha_last_error, 'HOME_ASSISTANT_URL and HOME_ASSISTANT_TOKEN are not set')
      Setting.set(:ha_last_polled_at, Time.current.iso8601)
      return
    end

    if client.available?
      Setting.set(:ha_last_status, 'ok')
      Setting.set(:ha_last_error, nil)
    else
      Setting.set(:ha_last_status, 'unreachable')
      Setting.set(:ha_last_error, 'Home Assistant API did not respond as expected')
    end

    Setting.set(:ha_last_polled_at, Time.current.iso8601)
  end
end
