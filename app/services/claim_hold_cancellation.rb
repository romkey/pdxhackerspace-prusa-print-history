# Cancels an unclaimed print that has already been paused Setting.claim_hold_max_pauses times
# for a claim and was continued again anyway. Called by PrintStartHolds#reapply_claim!.
class ClaimHoldCancellation
  MESSAGE = 'Cancelled automatically: it was continued without a claim after %d %s.'.freeze

  def initialize(job, client: nil)
    @job = job
    @client = client
  end

  # Returns true when the print was stopped.
  def cancel!
    PrinterControl.new(@job.printer, client: @client).stop
    record!
    true
  rescue PrinterControl::NotAllowed, PrinterConnection::Error => e
    Rails.logger.warn("[ClaimHoldCancellation] couldn't cancel job ##{@job.id}: #{e.message}")
    false
  end

  private

  def record!
    now = Time.current
    # claim_hold_at is refreshed so the poller doesn't read the printer catching up as a resume.
    @job.update!(status: 'cancelled', ended_at: now, claim_hold_at: now)
    event = @job.events.create!(event_type: 'cancelled', from_status: 'printing', to_status: 'cancelled',
                                occurred_at: now, message:)
    CaptureEventPhotoJob.perform_later(event.id) if @job.printer.camera_configured?
    ClaimEnforcementWebhookJob.perform_later(@job.id, ClaimEnforcementWebhook::CANCELLED, ['unclaimed'])
  end

  def message
    count = @job.claim_pause_count
    format(MESSAGE, count, 'pause'.pluralize(count))
  end
end
