require 'csv'

# Renders a user's print history as CSV.
class JobHistoryCsv
  HEADERS = JobHistoryRecords::FIELDS

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
    JobHistoryRecords.for(job).map { |field, value| %w[file printer].include?(field) ? safe(value) : value }
  end

  # Neutralise spreadsheet formula injection in user-influenced text.
  def safe(value)
    value.to_s.match?(/\A[=+\-@\t\r]/) ? "'#{value}" : value
  end
end
