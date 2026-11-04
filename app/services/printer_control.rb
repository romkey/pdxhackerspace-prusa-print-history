# Sends admin-initiated commands (submit/pause/resume/stop) to a printer via PrusaLink.
class PrinterControl
  class NotAllowed < StandardError; end

  SUBMIT_STATES = %w[IDLE FINISHED STOPPED READY].freeze
  GCODE_EXTENSIONS = %w[.gcode .bgcode .gco .g].freeze

  def initialize(printer, client: PrusaLink::Client.new(printer))
    @printer = printer
    @client = client
  end

  # Uploads a G-code file (an uploaded file responding to +original_filename+/+tempfile+) and starts printing it.
  def submit(upload)
    raise NotAllowed, "#{@printer.name} has no PrusaLink key configured." unless @printer.prusalink?

    filename = sanitize_filename(upload&.original_filename)
    state = @client.status.dig('printer', 'state').to_s.upcase
    raise NotAllowed, "Can't start a print while #{@printer.name} is #{state.downcase.presence || 'unknown'}." \
      unless SUBMIT_STATES.include?(state)

    File.open(upload.tempfile.path, 'rb') do |file|
      @client.upload_file(file, filename: filename, size: file.size)
    end
    PrinterPollJob.perform_later(@printer.id)
    filename
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

  def sanitize_filename(name)
    base = File.basename(name.to_s).gsub(/[^\w.\- ]/, '_').strip
    raise NotAllowed, 'Choose a G-code file to print.' if base.blank?
    raise NotAllowed, "#{base} isn't a G-code file (.gcode or .bgcode)." \
      unless GCODE_EXTENSIONS.include?(File.extname(base).downcase)

    base
  end

  # Asks the printer itself (not our possibly stale DB) what it is doing before acting.
  def perform(allowed_states, verb)
    raise NotAllowed, "#{@printer.name} has no PrusaLink key configured." unless @printer.prusalink?

    job = @client.job
    raise NotAllowed, "#{@printer.name} has no active job to #{verb}." if job.blank? || job['id'].blank?

    state = current_state(job)
    raise NotAllowed, "Can't #{verb} while #{@printer.name} is #{state.downcase.presence || 'unknown'}." \
      unless allowed_states.include?(state)

    yield job['id']
    PrinterPollJob.perform_later(@printer.id)
  end

  def current_state(job)
    state = job['state'].to_s.upcase
    state = @client.status.dig('printer', 'state').to_s.upcase if state.blank?
    state
  end
end
