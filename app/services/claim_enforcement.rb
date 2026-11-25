# Claim enforcement (Setting.enforce_claims?): PrintStartHolds pauses a print that is still
# unclaimed when the poller first sees it start and marks it with claim_hold_at. Once someone
# claims it, this continues it, unless it is also held for its filament. Each continue is
# reported to the optional webhook.
class ClaimEnforcement
  def self.release!(job, client: nil)
    new(job, client:).release!
  end

  def initialize(job, client: nil)
    @job = job
    @client = client
  end

  # Continues a held print once it has an owner. Connection errors propagate so the caller
  # (ClaimHoldReleaseJob) can retry; a print that is no longer paused just loses its hold.
  def release!
    return false if @job.claim_hold_at.blank? || @job.owner_id.blank?

    if !@job.active? || @job.filament_hold_at.present?
      drop_hold!
      return false
    end

    control.resume
    @job.update!(claim_hold_at: nil)
    ClaimEnforcementWebhookJob.perform_later(@job.id, ClaimEnforcementWebhook::CONTINUED, ['claimed'])
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

  def drop_hold!
    @job.update!(claim_hold_at: nil)
  end
end
