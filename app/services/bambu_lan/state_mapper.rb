module BambuLan
  # Bambu gcode_state values, expressed as the PrusaLink state names
  # PrinterPoller already understands.
  module StateMapper
    def self.prusa_state(print)
      raw = print['gcode_state'].to_s.upcase
      return 'IDLE' if raw == 'IDLE'
      return 'FINISHED' if raw == 'FINISH'
      return failed_state(print) if raw == 'FAILED'
      return 'ATTENTION' if attention?(print, raw)
      return 'PAUSED' if raw == 'PAUSE'

      'PRINTING'
    end

    def self.failed_state(print)
      ErrorDetail.cancelled?(print) ? 'STOPPED' : 'ERROR'
    end

    # A print the printer still calls RUNNING is underway. Leftover HMS from a
    # cancel must not mark that whole job as attention. A pause still does.
    def self.attention?(print, raw)
      return false if %w[IDLE FINISH FAILED RUNNING PREPARE].include?(raw)
      return true if ErrorDetail.hms?(print)

      raw == 'PAUSE' && ErrorDetail.error_code(print).present?
    end
  end
end
