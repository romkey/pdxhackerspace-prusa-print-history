# Sends admin-initiated control commands (pause/resume/stop) to a printer's current PrusaLink job.
class PrinterControl
  class NotAllowed < StandardError; end

  def initialize(printer, client: PrusaLink::Client.new(printer))
    @printer = printer
    @client = client
  end

  def pause
    perform(%w[PRINTING], 'pause') { |id| @client.pause_job(id) }
  end

  def resume
    perform(%w[PAUSED], 'resume') { |id| @client.resume_job(id) }
  end

  def stop
    perform(%w[PRINTING PAUSED ATTENTION ERROR], 'stop') { |id| @client.stop_job(id) }
  end

  private

  # Asks the printer itself (not our possibly stale DB) what it is doing before acting.
  def perform(allowed_states, verb)
    raise NotAllowed, "#{@printer.name} has no PrusaLink key configured." unless @printer.prusalink?

    job = @client.job
    raise NotAllowed, "#{@printer.name} has no active job to #{verb}." if job.blank? || job['id'].blank?

    state = job['state'].to_s.upcase
    state = @client.status.dig('printer', 'state').to_s.upcase if state.blank?
    raise NotAllowed, "Can't #{verb} while #{@printer.name} is #{state.downcase.presence || 'unknown'}." \
      unless allowed_states.include?(state)

    yield job['id']
    PrinterPollJob.perform_later(@printer.id)
  end
end
