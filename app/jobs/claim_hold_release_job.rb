# Continues a print that claim enforcement paused, once it has been claimed.
class ClaimHoldReleaseJob < ApplicationJob
  queue_as :default

  retry_on PrinterConnection::Error, wait: 30.seconds, attempts: 10

  def perform(job_id)
    job = Job.find_by(id: job_id)
    return if job.nil?

    ClaimEnforcement.release!(job)
  end
end
