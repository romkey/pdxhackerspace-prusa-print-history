# Pauses a print the moment the poller first sees it start, when an enforcement setting says
# it has to wait: nobody has claimed it (Setting.enforce_claims?), or its printer can't run its
# filament (Setting.enforce_filament_types?). One pause covers both, and each reason is kept
# on the job (claim_hold_at, filament_hold_at + filament_hold_reason) so the dashboard can
# say why. ClaimEnforcement continues a claim-only hold once the print is claimed; a filament
# hold waits for someone to deal with the printer.
class PrintStartHolds
  CLAIM_MESSAGE = 'Paused automatically because nobody has claimed this print. Claim it to continue.'.freeze
  FILAMENT_MESSAGE = 'Paused automatically because this printer may not run this filament: %s'.freeze

  def self.apply!(job, client: nil)
    new(job, client:).apply!
  end

  def initialize(job, client: nil)
    @job = job
    @client = client
  end

  # Returns true when the print was paused.
  def apply!
    return false unless @job.status == 'printing'

    claim = claim_hold?
    filament = filament_problem
    return false unless claim || filament

    PrinterControl.new(@job.printer, client: @client).pause
    record!(claim, filament)
    true
  rescue PrinterControl::NotAllowed, PrinterConnection::Error => e
    Rails.logger.warn("[PrintStartHolds] couldn't pause job ##{@job.id}: #{e.message}")
    false
  end

  private

  def claim_hold?
    Setting.enforce_claims? && @job.owner_id.nil? && @job.claim_hold_at.nil?
  end

  def filament_problem
    return nil unless Setting.enforce_filament_types? && @job.filament_hold_at.nil?

    FilamentCheck.problem(@job)
  end

  def record!(claim, filament)
    now = Time.current
    @job.update!(status: 'paused', claim_hold_at: (now if claim), filament_hold_at: (now if filament),
                 filament_hold_reason: filament)
    event = @job.events.create!(event_type: 'paused', from_status: 'printing', to_status: 'paused',
                                occurred_at: now, message: message(claim, filament))
    CaptureEventPhotoJob.perform_later(event.id) if @job.printer.camera_configured?
    ClaimEnforcementWebhookJob.perform_later(@job.id, ClaimEnforcementWebhook::PAUSED, reasons(claim, filament))
  end

  def message(claim, filament)
    [(format(FILAMENT_MESSAGE, filament) if filament), (CLAIM_MESSAGE if claim)].compact.join(' ')
  end

  def reasons(claim, filament)
    [('filament_not_allowed' if filament), ('unclaimed' if claim)].compact
  end
end
