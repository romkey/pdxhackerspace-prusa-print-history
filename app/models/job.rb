class Job < ApplicationRecord
  STATUSES = %w[pending printing paused attention error finished cancelled].freeze
  ACTIVE_STATUSES   = %w[printing paused attention error].freeze
  TERMINAL_STATUSES = %w[finished cancelled].freeze

  belongs_to :printer
  belongs_to :owner, class_name: 'User', optional: true

  has_many :tools,              -> { order(:tool_index) },  dependent: :destroy, inverse_of: :job
  has_many :telemetry_readings, -> { order(:recorded_at) }, dependent: :destroy, inverse_of: :job
  has_many :events, -> { order(:occurred_at) }, class_name: 'JobEvent', dependent: :destroy, inverse_of: :job

  validates :filename, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :prusalink_job_id, uniqueness: { scope: :printer_id, allow_nil: true }

  scope :active,    -> { where(status: ACTIVE_STATUSES) }
  scope :terminal,  -> { where(status: TERMINAL_STATUSES) }
  scope :recent,    -> { reorder(started_at: :desc, created_at: :desc) }
  scope :owned_by,  ->(user) { where(owner_id: user&.id) }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def duration_seconds
    return total_duration_seconds if total_duration_seconds.present?
    return nil if started_at.nil?

    ((ended_at || Time.current) - started_at).to_i
  end
end
