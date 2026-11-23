require 'csv'

# Renders a user's print history as CSV.
class JobHistoryCsv
  HEADERS = %w[
    file printer status started_at ended_at duration_seconds filament_grams cleared_at clear_outcome
  ].freeze

  def self.call(jobs)
    new(jobs).to_csv
  end

  def initialize(jobs)
    @jobs = jobs
  end

  def to_csv
    CSV.generate do |csv|
      csv << HEADERS
      @jobs.each { |job| csv << row(job) }
    end
  end

  private

  def row(job)
    [
      safe(job.filename), safe(job.printer.name), job.status, time(job.started_at), time(job.ended_at),
      job.duration_seconds, job.total_filament_grams&.to_f, time(job.cleared_at), job.clear_outcome
    ]
  end

  def time(value)
    value&.utc&.iso8601
  end

  # Neutralise spreadsheet formula injection in user-influenced text.
  def safe(value)
    value.to_s.match?(/\A[=+\-@\t\r]/) ? "'#{value}" : value
  end
end
