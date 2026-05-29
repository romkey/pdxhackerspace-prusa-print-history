class JobFinishedNotificationJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    job = Job.find_by(id: job_id)
    return if job.nil? || job.owner.blank?
    return if job.finished_notified_at.present?

    job.update!(finished_notified_at: Time.current)
    JobNotificationService.notify_print_finished(job)
  end
end
