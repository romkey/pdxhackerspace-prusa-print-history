class Setting < ApplicationRecord
  KEYS = %w[
    default_ambient_sensor
    dashboard_heading
    footer_text
    footer_link_label
    footer_link_url
    ha_last_polled_at
    ha_last_error
    ha_last_status
  ].freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }

  def self.fetch(key, default = nil)
    record = find_by(key: key.to_s)
    return default if record.nil?

    record.value
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key.to_s)
    record.value = value&.to_s
    record.save!
    record.value
  end

  def self.default_ambient_sensor
    fetch(:default_ambient_sensor)
  end

  def self.default_ambient_sensor=(value)
    set(:default_ambient_sensor, value.presence)
  end

  def self.dashboard_heading
    fetch(:dashboard_heading)
  end

  def self.dashboard_heading=(value)
    set(:dashboard_heading, value.presence)
  end

  def self.footer_text
    fetch(:footer_text)
  end

  def self.footer_text=(value)
    set(:footer_text, value.presence)
  end

  def self.footer_link_label
    fetch(:footer_link_label)
  end

  def self.footer_link_label=(value)
    set(:footer_link_label, value.presence)
  end

  def self.footer_link_url
    fetch(:footer_link_url)
  end

  def self.footer_link_url=(value)
    set(:footer_link_url, value.presence)
  end

  def self.home_assistant_health
    {
      status: fetch(:ha_last_status),
      polled_at: parse_time(fetch(:ha_last_polled_at)),
      error: fetch(:ha_last_error)
    }
  end

  def self.parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value)
  rescue ArgumentError
    nil
  end
end
