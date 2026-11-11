module BambuLan
  # PrusaLink-shaped client backed by a Bambu printer in LAN Developer Mode.
  # PrinterPoller, PrinterCamera, and PrinterControl talk to it the same way
  # they talk to PrusaLink::Client.
  class Client
    def initialize(printer, mqtt: nil, ftps: nil, camera: nil)
      @printer = printer
      @mqtt = mqtt || Mqtt.new(printer)
      @ftps = ftps || Ftps.new(printer)
      @camera = camera || Camera.new(printer)
    end

    delegate :status, :job, :info, to: :view

    def legacy_printer
      nil
    end

    def file_info(_storage_path)
      nil
    end

    def download(path)
      FileCache.read_preview(path)
    end

    def camera_snapshot
      @camera.snapshot
    end

    def pause_job(_job_id)
      @mqtt.command('print', 'pause')
    end

    def resume_job(_job_id)
      @mqtt.command('print', 'resume')
    end

    def stop_job(_job_id)
      @mqtt.command('print', 'stop')
    end

    # Name and return value match PrusaLink::Client, which PrinterControl calls.
    def upload_file(io, filename:, size:, storage: 'cache', print: true) # rubocop:disable Naming/PredicateMethod
      archive = Archive.read(io)
      io.rewind if io.respond_to?(:rewind)
      Rails.logger.info("[BambuLan] upload #{filename} (#{size} bytes) for printer ##{@printer.id}")
      @ftps.upload(io, "#{storage}/#{filename}")
      return true unless print

      fields = ProjectFile.fields(filename: filename, archive: archive, report: online_report)
      @mqtt.command('print', 'project_file', fields)
      true
    end

    private

    def view
      @view ||= Report.new(online_report, printer: @printer, ftps: @ftps)
    end

    def online_report
      return @online_report if @online_report

      message = @mqtt.fetch_report
      state = message.dig('print', 'gcode_state').to_s.upcase
      raise Error, 'The printer did not send a status report.' if state.blank?
      raise Error, 'The printer reported it is offline.' if state == 'OFFLINE'

      Rails.logger.info("[BambuLan] printer ##{@printer.id} #{state}")
      @online_report = message
    end
  end
end
