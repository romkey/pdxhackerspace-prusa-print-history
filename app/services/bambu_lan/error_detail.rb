module BambuLan
  # Turns print_error / HMS codes from a status report into a short timeline
  # message, and decides whether FAILED was a user cancel.
  module ErrorDetail
    KNOWN = {
      '05004003' => 'The printer could not parse the file. Send the job again.',
      '0500c010' => 'The printer could not read its storage.'
    }.freeze

    def self.message(print)
      parts = []
      text = print_error_text(print)
      parts << text if text
      parts.concat(hms_texts(print))
      parts << 'The print was cancelled.' if parts.empty? && cancelled?(print)
      parts.presence&.join(' ')
    end

    def self.cancelled?(print)
      return true if print['fail_reason'].to_s.match?(/cancel/i)
      return false unless print['gcode_state'].to_s.upcase == 'FAILED'

      error_code(print).nil? && !hms?(print)
    end

    def self.hms?(print)
      hms_texts(print).any?
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
