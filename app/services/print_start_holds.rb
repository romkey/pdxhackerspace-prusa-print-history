# Pauses a print the moment the poller first sees it start, when an enforcement setting says
# it has to wait: nobody has claimed it (Printer#enforces_claims?), or its printer can't run its
# filament (Printer#enforces_filament_types?). One pause covers both, and each reason is kept
# on the job (claim_hold_at, filament_hold_at + filament_hold_reason) so the dashboard can
# say why. ClaimEnforcement continues a claim-only hold once the print is claimed; a filament
# hold waits for someone to deal with the printer.
#
# A claim hold also sticks: PrinterPoller calls reapply_claim! whenever a print is running
# unclaimed on a claim-enforcing printer after the start (resumed from the printer or a
# slicer, or enforcement turned on mid-print), and it gets paused again. Resuming is still
# taken as someone at the printer accepting a filament hold. Each claim pause is counted
# (Job#claim_pause_count); once a print has been paused Setting.claim_hold_max_pauses times,
# continuing it again without a claim cancels it (ClaimHoldCancellation).
class PrintStartHolds
  CLAIM_MESSAGE = 'Paused automatically because nobody has claimed this print (pause %<count>d of %<max>d). ' \
                  'Claim it to continue.'.freeze
  FINAL_CLAIM_WARNING = 'This is the last pause: if it is continued again without a claim, it will be cancelled.'.freeze
  FILAMENT_MESSAGE = 'Paused automatically because this printer may not run this filament: %s'.freeze

  def self.apply!(job, client: nil)
    new(job, client:).apply!
  end

  def self.reapply_claim!(job, client: nil)
    new(job, client:).reapply_claim!
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

    pause!(claim, filament)
  end

  # Pauses a print that is running unclaimed on a claim-enforcing printer, or cancels it once
  # it has used up its pauses. Returns true when the print was paused or cancelled.
  def reapply_claim!
    return false unless @job.status == 'printing' && claim_required?
    return ClaimHoldCancellation.new(@job, client: @client).cancel! if @job.claim_pauses_used_up?

    pause!(true, nil)
  end

  private

  def pause!(claim, filament)
    PrinterControl.new(@job.printer, client: @client).pause
    record!(claim, filament)
    true
  rescue PrinterControl::NotAllowed, PrinterConnection::Error => e
    Rails.logger.warn("[PrintStartHolds] couldn't pause job ##{@job.id}: #{e.message}")
    false
  end

  def claim_required?
    @job.printer.enforces_claims? && @job.owner_id.nil?
  end

  def claim_hold?
    claim_required? && @job.claim_hold_at.nil?
  end

  def filament_problem
    return nil unless @job.printer.enforces_filament_types? && @job.filament_hold_at.nil?

    FilamentCheck.problem(@job)
  end

  def record!(claim, filament)
    now = Time.current
    @job.update!(status: 'paused', claim_hold_at: (now if claim), filament_hold_at: (now if filament),
                 filament_hold_reason: filament, claim_pause_count: @job.claim_pause_count + (claim ? 1 : 0))
    event = @job.events.create!(event_type: 'paused', from_status: 'printing', to_status: 'paused',
                                occurred_at: now, message: message(claim, filament))
    CaptureEventPhotoJob.perform_later(event.id) if @job.printer.camera_configured?
    ClaimEnforcementWebhookJob.perform_later(@job.id, ClaimEnforcementWebhook::PAUSED, reasons(claim, filament))
  end

  def message(claim, filament)
    [(format(FILAMENT_MESSAGE, filament) if filament), (claim_message if claim)].compact.join(' ')
  end

  def claim_message
    text = format(CLAIM_MESSAGE, count: @job.claim_pause_count, max: Setting.claim_hold_max_pauses)
    @job.claim_pauses_used_up? ? "#{text} #{FINAL_CLAIM_WARNING}" : text
  end

  def reasons(claim, filament)
    [('filament_not_allowed' if filament), ('unclaimed' if claim)].compact
  end
end
