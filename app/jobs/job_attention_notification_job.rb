class JobAttentionNotificationJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    job = Job.find_by(id: job_id)
    return if job.nil? || job.owner.blank?

    JobNotificationService.notify_print_attention(job)
  end
end
