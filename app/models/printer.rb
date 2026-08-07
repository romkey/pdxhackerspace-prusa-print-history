class Printer < ApplicationRecord
  encrypts :prusalink_key
  encrypts :prusa_connect_token

  before_save :ensure_prusa_connect_fingerprint

  HA_ENCLOSURE_TEMP_SUFFIX = '_bme680_temperature'.freeze
  HA_HUMIDITY_SUFFIX       = '_bme680_humidity'.freeze
  OPERATIONAL_STATES  = %w[unknown idle printing paused attention error finished cancelled].freeze
  ENVIRONMENT_COLUMNS = %w[
    operational_state ambient_temp enclosure_temp enclosure_humidity environment_updated_at
  ].freeze
  CONNECTIVITY_COLUMNS = %w[prusalink_reachable prusalink_checked_at].freeze

  has_many :jobs, dependent: :destroy
  has_many :photo_captures, dependent: :destroy
  has_many :printer_events, -> { order(:occurred_at) }, dependent: :destroy, inverse_of: :printer
  has_many :printer_heads, -> { order(:tool_index) }, dependent: :destroy, inverse_of: :printer

  validates :name,     presence: true, uniqueness: { case_sensitive: false }
  validates :hostname, presence: true
  validates :operational_state, inclusion: { in: OPERATIONAL_STATES }, if: :environment_tracking?

  scope :ordered, -> { order(:name) }

  def self.environment_tracking?
    column_names.include?('operational_state')
  end

  delegate :environment_tracking?, to: :class

  def self.connection_tracking?
    column_names.include?('prusalink_reachable')
  end

  delegate :connection_tracking?, to: :class

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

  def camera_configured?
    camera? || prusalink?
  end

  def prusalink?
    hostname.present? && prusalink_key.present?
  end

  def prusa_connect?
    prusa_connect_token.present? && prusa_connect_fingerprint.present?
  end

  def home_assistant?
    ha_base_sensor.present?
  end

  def current_job
    jobs.where(status: %w[printing paused attention error]).order(started_at: :desc).first
  end

  # The job whose photos the printer's camera is currently showing: the active one, or
  # whatever was printed most recently and may still be sitting on the bed.
  def latest_job
    current_job || jobs.recent.first
  end

  def display_status
    job_status = current_job&.status
    if environment_tracking? && operational_state.present? && operational_state != 'unknown'
      return job_status if job_status.present?

      return operational_state
    end

    job_status || 'idle'
  end

  def idle?
    display_status == 'idle'
  end

  def prusalink_connection_status
    return :unconfigured unless prusalink?

    return :unknown unless connection_tracking? && !prusalink_reachable.nil?

    prusalink_reachable ? :reachable : :unreachable
  end

  private

  def ensure_prusa_connect_fingerprint
    return if prusa_connect_token.blank?

    self.prusa_connect_fingerprint ||= PrusaConnect::Fingerprint.generate
  end
end
