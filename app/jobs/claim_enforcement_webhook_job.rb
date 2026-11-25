class ClaimEnforcementWebhookJob < ApplicationJob
  queue_as :default

  retry_on ClaimEnforcementWebhook::Error, wait: :polynomially_longer, attempts: 5

  def perform(job_id, action)
    job = Job.find_by(id: job_id)
    return if job.nil?

    ClaimEnforcementWebhook.deliver(job, action)
  end
end
