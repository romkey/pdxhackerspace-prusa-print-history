class TelemetryReading < ApplicationRecord
  belongs_to :job

  validates :recorded_at, presence: true

  scope :ordered, -> { reorder(:recorded_at) }

  def tool_temp(index)
    tool_temps[index.to_s] || tool_temps[index.to_i]
  end
end
