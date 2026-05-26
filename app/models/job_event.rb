class JobEvent < ApplicationRecord
  EVENT_TYPES = %w[
    started
    status_changed
    attention
    error
    paused
    resumed
    finished
    cancelled
  ].freeze

  belongs_to :job
  has_one_attached :photo

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true

  scope :ordered, -> { reorder(:occurred_at) }
  scope :recent,  -> { reorder(occurred_at: :desc) }
end
