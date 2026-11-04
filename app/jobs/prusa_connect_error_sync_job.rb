# Fills in a JobEvent's message with the detail Prusa Connect has about an error/attention
# transition. Connect lags the printer by a few seconds, so an empty answer is retried.
class PrusaConnectErrorSyncJob < ApplicationJob
  queue_as :default

  class NoDetailYet < StandardError; end

  retry_on NoDetailYet, wait: 30.seconds, attempts: 4 do |_job, _error|
    Rails.logger.info('PrusaConnectErrorSyncJob: Connect had no error detail; giving up')
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(job_event_id)
    event = JobEvent.find(job_event_id)
    return if event.connect_detail.present?

    result = PrusaConnect::ErrorDetail.fetch(event.job.printer, since: event.occurred_at)
    raise NoDetailYet if result.nil?

    store(event, result)
  rescue PrusaConnect::AuthError => e
    Rails.logger.warn("PrusaConnectErrorSyncJob: #{e.message}")
  rescue PrusaConnect::Error => e
    Rails.logger.warn("PrusaConnectErrorSyncJob: #{e.message}")
    raise NoDetailYet
  end

  private

  def store(event, result)
    event.update!(message: [event.message, result.message].compact_blank.join(' — '), connect_detail: result.raw)
    PrusaConnectCredential.current&.update!(last_synced_at: Time.current, last_error: nil)
  end
end
