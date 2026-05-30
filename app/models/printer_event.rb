class PrinterEvent < ApplicationRecord
  EVENT_TYPES = %w[
    filament_change
  ].freeze

  belongs_to :printer

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
  validates :tool_index, presence: true, if: -> { event_type == 'filament_change' }

  scope :recent, -> { reorder(occurred_at: :desc) }
end
