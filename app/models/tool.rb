class Tool < ApplicationRecord
  belongs_to :job

  validates :tool_index, presence: true,
                         numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                         uniqueness: { scope: :job_id }
  validates :nozzle_size_mm, presence: true,
                             numericality: { greater_than: 0 }

  def label
    parts = ["T#{tool_index}", "#{nozzle_size_mm.to_f.round(2)} mm"]
    parts << 'HF' if high_flow?
    parts << material if material.present?
    parts.join(' \u00b7 ')
  end
end
