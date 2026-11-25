# Claim enforcement (Setting.enforce_claims?): a print that is still unclaimed when the poller
# first sees it start is paused on the printer and marked with claim_hold_at; once someone
# claims it, it is continued. Each pause and continue is reported to the optional webhook.
class ClaimEnforcement
  HOLD_MESSAGE = 'Paused automatically because nobody has claimed this print. Claim it to continue.'.freeze

  def self.hold_if_unclaimed!(job, client: nil)
    new(job, client:).hold_if_unclaimed!
  end

  def self.release!(job, client: nil)
    new(job, client:).release!
  end

  def initialize(job, client: nil)
    @job = job
    @client = client
  end

  # Returns true when the print was paused.
  def hold_if_unclaimed!
    return false unless Setting.enforce_claims?
    return false if @job.owner_id.present? || @job.claim_hold_at.present? || @job.status != 'printing'

    control.pause
    record_hold!
    true
  rescue PrinterControl::NotAllowed, PrinterConnection::Error => e
    Rails.logger.warn("[ClaimEnforcement] couldn't pause job ##{@job.id}: #{e.message}")
    false
  end

  # Continues a held print once it has an owner. Connection errors propagate so the caller
  # (ClaimHoldReleaseJob) can retry; a print that is no longer paused just loses its hold.
  def release!
    return false if @job.claim_hold_at.blank? || @job.owner_id.blank?

    unless @job.active?
      drop_hold!
      return false
    end

    control.resume
    @job.update!(claim_hold_at: nil)
    ClaimEnforcementWebhookJob.perform_later(@job.id, ClaimEnforcementWebhook::CONTINUED)
    true
  rescue PrinterControl::NotAllowed => e
    Rails.logger.info("[ClaimEnforcement] not continuing job ##{@job.id}: #{e.message}")
    drop_hold!
    false
  end

  private

  def control
    PrinterControl.new(@job.printer, client: @client)
  end

  def record_hold!
    now = Time.current
    @job.update!(status: 'paused', claim_hold_at: now)
    event = @job.events.create!(event_type: 'paused', from_status: 'printing', to_status: 'paused',
                                occurred_at: now, message: HOLD_MESSAGE)
    CaptureEventPhotoJob.perform_later(event.id) if @job.printer.camera_configured?
    ClaimEnforcementWebhookJob.perform_later(@job.id, ClaimEnforcementWebhook::PAUSED)
  end

  def drop_hold!
    @job.update!(claim_hold_at: nil)
  end
end
