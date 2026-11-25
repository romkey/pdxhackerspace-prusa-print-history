class Setting < ApplicationRecord
  extend ApiSettings

  DEFAULT_PRUSA_UNTRAINED_MESSAGE =
    "You don't appear to be trained on the Prusa printers. If you haven't completed training yet, " \
    "please don't use the printers — request training in #3dprinting on Slack.".freeze
  DEFAULT_PRUSA_TRAINED_ACCOUNT_MESSAGE =
    'If you have already been trained on the Prusa printers, please ask an admin to add Prusa to your account.'.freeze

  DEFAULT_TRAINING_TOPICS = %w[Prusa].freeze

  DEFAULT_IMAGE_RETENTION_MONTHS = 3
  DEFAULT_JOB_HISTORY_RETENTION_MONTHS = 12

  KEYS = %w[
    default_ambient_sensor
    dashboard_heading
    footer_text
    footer_link_label
    footer_link_url
    prusa_untrained_message
    prusa_trained_account_message
    image_retention_months
    delete_job_history
    job_history_retention_months
    enforce_claims
    enforce_claims_webhook_url
    training_topics
    enforce_filament_types
    ha_last_polled_at
    ha_last_error
    ha_last_status
  ].concat(ApiSettings::KEYS).freeze

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

  def self.prusa_untrained_message
    message_for(:prusa_untrained_message, DEFAULT_PRUSA_UNTRAINED_MESSAGE)
  end

  def self.prusa_untrained_message=(value)
    set(:prusa_untrained_message, value.to_s.strip)
  end

  def self.prusa_trained_account_message
    message_for(:prusa_trained_account_message, DEFAULT_PRUSA_TRAINED_ACCOUNT_MESSAGE)
  end

  def self.prusa_trained_account_message=(value)
    set(:prusa_trained_account_message, value.to_s.strip)
  end

  def self.image_retention_months
    positive_integer_for(:image_retention_months, DEFAULT_IMAGE_RETENTION_MONTHS)
  end

  def self.image_retention_months=(value)
    set(:image_retention_months, value.presence)
  end

  def self.delete_job_history?
    fetch(:delete_job_history) == 'true'
  end

  def self.delete_job_history=(value)
    set(:delete_job_history, ActiveModel::Type::Boolean.new.cast(value) ? 'true' : 'false')
  end

  def self.job_history_retention_months
    positive_integer_for(:job_history_retention_months, DEFAULT_JOB_HISTORY_RETENTION_MONTHS)
  end

  def self.job_history_retention_months=(value)
    set(:job_history_retention_months, value.presence)
  end

  # When on, only members trained on the printers (and admins) may claim, and a print that is
  # unclaimed when it starts is paused until someone claims it.
  def self.enforce_claims?
    fetch(:enforce_claims) == 'true'
  end

  def self.enforce_claims=(value)
    set(:enforce_claims, ActiveModel::Type::Boolean.new.cast(value) ? 'true' : 'false')
  end

  # When on, a print whose filament the printer can't run (see FilamentType#allowed_on?) is
  # paused when it starts.
  def self.enforce_filament_types?
    fetch(:enforce_filament_types) == 'true'
  end

  def self.enforce_filament_types=(value)
    set(:enforce_filament_types, ActiveModel::Type::Boolean.new.cast(value) ? 'true' : 'false')
  end

  # Optional URL that gets a JSON POST whenever a print is paused or continued for claim enforcement.
  def self.enforce_claims_webhook_url
    fetch(:enforce_claims_webhook_url).presence
  end

  def self.enforce_claims_webhook_url=(value)
    set(:enforce_claims_webhook_url, value.to_s.strip.presence)
  end

  # Training topics admins can require per printer. Names match entries in Authentik's
  # trained_on claim (case-insensitively). Stored one per line.
  def self.training_topics
    value = fetch(:training_topics)
    return DEFAULT_TRAINING_TOPICS.dup if value.nil?

    TrainingTopics.normalize(value)
  end

  def self.training_topics=(value)
    set(:training_topics, TrainingTopics.normalize(value).join("\n"))
  end

  def self.positive_integer_for(key, default)
    number = fetch(key).to_i
    number.positive? ? number : default
  end

  def self.message_for(key, default)
    record = find_by(key: key.to_s)
    return default if record.nil?

    record.value.presence
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

  private_class_method :message_for, :positive_integer_for, :parse_time
end
