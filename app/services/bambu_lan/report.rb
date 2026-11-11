module BambuLan
  # One Bambu status report, shaped like the hashes PrinterPoller already reads
  # from PrusaLink.
  class Report
    UNIX_TIME = 1_000_000_000

    def initialize(message, printer:, ftps:)
      @message = message
      @printer = printer
      @ftps = ftps
      @print = message['print'].is_a?(Hash) ? message['print'] : {}
    end

    def status
      payload = { 'printer' => printer_fields, 'tools' => tools }
      payload['job'] = job if job
      payload
    end

    def job
      return nil if idle?

      @job ||= build_job
    end

    def info
      diameter = tools.dig(0, 'nozzle_diameter')
      return {} if diameter.blank?

      { 'nozzle_diameter' => diameter }
    end

    private

    def idle?
      @print['gcode_state'].to_s.upcase == 'IDLE'
    end

    def printer_fields
      fields = {
        'state' => StateMapper.prusa_state(@print),
        'temp_nozzle' => tools.dig(0, 'temp'),
        'temp_bed' => Tools.bed(@message)
      }
      chamber = Tools.chamber(@message, model: @printer.model)
      fields['temp_chamber'] = chamber unless chamber.nil?
      detail = ErrorDetail.message(@print)
      fields['error_message'] = detail if detail.present?
      fields
    end

    def tools
      @tools ||= Tools.entries(@message, material: Materials.loaded_type(@print))
    end

    def build_job
      payload = { 'id' => job_id, 'state' => StateMapper.prusa_state(@print) }
      payload['progress'] = progress unless progress.nil?
      payload['time_remaining'] = remaining_seconds unless remaining_seconds.nil?
      payload['time_printing'] = printing_seconds unless printing_seconds.nil?
      payload['filename'] = filename if filename
      payload['file'] = file_hash
      payload
    end

    def progress
      return 100.0 if @print['gcode_state'].to_s.upcase == 'FINISH'

      Tools.number(@print['mc_percent'])
    end

    def remaining_seconds
      minutes = Tools.number(@print['mc_remaining_time'])
      return nil if minutes.nil?

      (minutes * 60).to_i
    end

    def printing_seconds
      start = @print['gcode_start_time'].to_i
      return nil if start < UNIX_TIME

      [Time.current.to_i - start, 0].max
    end

    def filename
      @print['subtask_name'].to_s.strip.presence || File.basename(@print['gcode_file'].to_s).presence
    end

    def job_id
      %w[task_id subtask_id].each do |key|
        value = @print[key].to_s
        return value if value.present? && value != '0'
      end
      start = @print['gcode_start_time'].to_s
      return "local-#{start}" if start.present? && start != '0'

      "local-#{filename.presence || 'print'}"
    end

    def file_hash
      hash = {}
      hash['display_name'] = filename if filename
      hash['name'] = filename if filename
      apply_file_details(hash, file_details)
      hash
    end

    def apply_file_details(hash, details)
      return if details.blank?

      hash['meta'] = { 'filament used [g]' => details['grams'] } if details['grams']
      hash['refs'] = { 'thumbnail' => details['token'] } if details['token']
    end

    def file_details
      return @file_details if defined?(@file_details)

      @file_details = load_file_details
    end

    def load_file_details
      path = remote_3mf
      return nil if path.blank?

      FileCache.fetch("printer-#{@printer.id}-#{job_id}-#{path}", expires_in: 6.hours) { download_details(path) }
    rescue Error => e
      Rails.logger.warn("[BambuLan] file metadata skipped for printer ##{@printer.id}: #{e.message}")
      nil
    end

    def download_details(path)
      archive = Archive.parse(@ftps.download(path))
      return nil if archive.nil?

      details = {}
      details['grams'] = archive.grams unless archive.grams.nil?
      token = FileCache.store_preview(archive.png)
      details['token'] = token if token
      details.presence
    end

    def remote_3mf
      file = @print['gcode_file'].to_s
      return nil unless file.downcase.end_with?('.3mf')

      file.sub(%r{\Aftp://}i, '').sub(%r{\A/+}, '')
    end
  end
end
