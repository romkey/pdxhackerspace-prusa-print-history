class Printer < ApplicationRecord
  encrypts :prusalink_key

  HA_ENCLOSURE_TEMP_SUFFIX = '_bme680_temperature'.freeze
  HA_HUMIDITY_SUFFIX       = '_bme680_humidity'.freeze

  has_many :jobs, dependent: :destroy

  validates :name,     presence: true, uniqueness: { case_sensitive: false }
  validates :hostname, presence: true

  scope :ordered, -> { order(:name) }

  def enclosure_temp_sensor
    return nil if ha_base_sensor.blank?

    "#{ha_base_sensor}#{HA_ENCLOSURE_TEMP_SUFFIX}"
  end

  def humidity_sensor
    return nil if ha_base_sensor.blank?

    "#{ha_base_sensor}#{HA_HUMIDITY_SUFFIX}"
  end

  def camera?
    camera_url.present?
  end

  def prusalink?
    hostname.present? && prusalink_key.present?
  end

  def home_assistant?
    ha_base_sensor.present?
  end

  def current_job
    jobs.where(status: %w[printing paused attention error]).order(started_at: :desc).first
  end
end
