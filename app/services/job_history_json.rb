# Renders a user's print history as JSON.
class JobHistoryJson
  def self.call(jobs)
    JSON.pretty_generate(jobs.map { |job| JobHistoryRecords.for(job) })
  end
end
