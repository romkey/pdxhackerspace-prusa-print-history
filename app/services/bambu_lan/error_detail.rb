module BambuLan
  # Turns print_error / HMS codes from a status report into a short timeline
  # message, and decides whether FAILED was a user cancel.
  module ErrorDetail
    KNOWN = {
      '05004003' => 'The printer could not parse the file. Send the job again.',
      '0500c010' => 'The printer could not read its storage.'
    }.freeze

    # Bambu reports a user cancel as this print_error for a few seconds, and
    # sometimes leaves it (or the matching HMS entry) set after the print stops.
    # 50348044 == 0x0300400C.
    CANCEL_CODE = '0300400c'.freeze

    def self.message(print)
      return 'The print was cancelled.' if cancelled?(print)

      parts = []
      text = print_error_text(print)
      parts << text if text
      parts.concat(hms_texts(print))
      parts.presence&.join(' ')
    end

    def self.cancelled?(print)
      return false unless print['gcode_state'].to_s.upcase == 'FAILED'
      return true if print['fail_reason'].to_s.match?(/cancel/i)
      return true if cancel_code?(error_code(print))

      error_code(print).nil? && !hms?(print)
    end

    def self.hms?(print)
      Array(print['hms']).any? { |item| fault_hms?(item) }
    end

    def self.error_code(print)
      raw = print['print_error']
      raw = print['mc_print_error_code'] if blank_code?(raw)
      normalize_code(raw)
    end

    def self.print_error_text(print)
      code = error_code(print)
      return nil if code.nil?

      KNOWN[code] || "Printer error 0x#{code}."
    end

    def self.hms_texts(print)
      Array(print['hms']).filter_map { |item| hms_text(item) }
    end

    def self.hms_text(item)
      raw = item.is_a?(Hash) ? item['code'] : item
      formatted = format_hms(raw)
      "HMS #{formatted}" if formatted
    end

    def self.fault_hms?(item)
      return false if cancel_hms?(item)

      hms_text(item).present?
    end

    def self.cancel_hms?(item)
      values = item.is_a?(Hash) ? [item['attr'], item['code']] : [item]
      values.any? { |value| cancel_code?(normalize_code(value)) }
    end

    def self.cancel_code?(code)
      code == CANCEL_CODE
    end

    def self.format_hms(code)
      hex = code.to_s.downcase.gsub(/[^0-9a-f]/, '')
      return nil if hex.blank? || hex.match?(/\A0+\z/)

      hex.scan(/.{1,4}/).join('-')
    end

    def self.blank_code?(raw)
      raw.nil? || raw.to_s.strip.empty? || raw.to_s.strip == '0'
    end

    def self.normalize_code(raw)
      return nil if blank_code?(raw)

      value = raw.is_a?(Integer) ? raw : parse_code_text(raw.to_s.strip)
      return nil if value.nil? || value.zero?

      format('%08x', value)
    end

    # Firmware sends print_error as a decimal integer. A string is hex only
    # when it is prefixed or contains a-f; an all-digit string stays decimal
    # so "83902467" is not read as 0x83902467.
    def self.parse_code_text(text)
      return text.sub(/\A0x/i, '').to_i(16) if text.match?(/\A0x[0-9a-f]+\z/i)
      return text.to_i(16) if text.match?(/[a-f]/i)

      Integer(text)
    rescue ArgumentError
      nil
    end
  end
end
