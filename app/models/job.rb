class Job < ApplicationRecord
  STATUSES = %w[pending printing paused attention error finished cancelled].freeze
  ACTIVE_STATUSES   = %w[printing paused attention error].freeze
  TERMINAL_STATUSES = %w[finished cancelled].freeze
  CLEAR_OUTCOMES = %w[success failed].freeze
  CLEAR_FAILURE_REASONS = {
    'spaghetti' => 'Spaghetti',
    'printer_jammed' => 'Printer jammed',
    'filament_issue' => 'Filament issue',
    'blobbed' => 'Blobbed',
    'other' => 'Other'
  }.freeze

  belongs_to :printer
  belongs_to :owner, class_name: 'User', optional: true
  belongs_to :cleared_by, class_name: 'User', optional: true

  has_many :tools,              -> { order(:tool_index) },  dependent: :destroy, inverse_of: :job
  has_many :telemetry_readings, -> { order(:recorded_at) }, dependent: :destroy, inverse_of: :job
  has_many :events, -> { order(:occurred_at) }, class_name: 'JobEvent', dependent: :destroy, inverse_of: :job
  has_many :photo_captures, dependent: :destroy

  has_one_attached :preview_image

  validates :filename, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :prusalink_job_id, uniqueness: { scope: :printer_id, allow_nil: true }

  scope :active,    -> { where(status: ACTIVE_STATUSES) }
  scope :terminal,  -> { where(status: TERMINAL_STATUSES) }
  scope :recent,    -> { reorder(started_at: :desc, created_at: :desc) }
  scope :owned_by,  ->(user) { where(owner_id: user&.id) }

  after_commit :sync_owner_print_time_totals, on: %i[create update]

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def label_printable?
    clearable?
  end

  def label_reprintable?
    cleared? && clear_outcome == 'success'
  end

  def clearable?
    (active? || status == 'finished') && cleared_at.nil?
  end

  def cleared?
    cleared_at.present?
  end

  def duration_seconds
    return total_duration_seconds if total_duration_seconds.present?
    return nil if started_at.nil?

    ((ended_at || Time.current) - started_at).to_i
  end

  private

  def sync_owner_print_time_totals
    return unless print_time_totals_dirty?

    PrintTimeAccounting.sync_users_for_job!(self, previous_owner_id: owner_id_before_last_save)
  end

  def print_time_totals_dirty?
    saved_change_to_status? ||
      saved_change_to_total_duration_seconds? ||
      saved_change_to_started_at? ||
      saved_change_to_ended_at? ||
      saved_change_to_owner_id?
  end
end
