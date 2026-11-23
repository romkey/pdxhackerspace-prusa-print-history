# The columns of a print-history export, shared by the CSV and JSON renderers.
module JobHistoryRecords
  FIELDS = %w[
    file printer status started_at ended_at duration_seconds filament_grams cleared_at clear_outcome
  ].freeze

  def self.for(job)
    FIELDS.zip(values(job)).to_h
  end

  def self.values(job)
    [
      job.filename, job.printer.name, job.status, time(job.started_at), time(job.ended_at),
      job.duration_seconds, job.total_filament_grams&.to_f, time(job.cleared_at), job.clear_outcome
    ]
  end

  def self.time(value)
    value&.utc&.iso8601
  end
  private_class_method :values, :time
end
