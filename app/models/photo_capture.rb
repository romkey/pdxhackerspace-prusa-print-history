class PhotoCapture < ApplicationRecord
  belongs_to :printer
  belongs_to :job, optional: true
  belongs_to :job_event, optional: true

  has_one_attached :image

  validates :captured_at, presence: true

  scope :chronological, -> { order(:captured_at) }
  scope :reverse_chronological, -> { reorder(captured_at: :desc) }
  scope :progress, -> { where(job_event_id: nil).where.not(job_id: nil) }
  scope :idle, -> { where(job_id: nil, job_event_id: nil) }

  def progress?
    job_id.present? && job_event_id.nil?
  end

  def idle?
    job_id.nil? && job_event_id.nil?
  end
end
