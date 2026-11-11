module BambuLan
  # Nozzle, bed, and chamber readings. Classic firmware puts degrees on `print`.
  # P2S and H2 put a packed integer on `device.extruder` and the chamber on `device.ctc`.
  module Tools
    # A real nozzle or bed reading is a few hundred degrees. P2S and H2 firmware
    # also sends a packed integer: the low 16 bits are the current temperature
    # and the high 16 bits are the target. 16711936 is 256 °C at a 255 °C target.
    DEGREE_LIMIT = 500

    def self.entries(report, material:)
      print = print_hash(report)
      dev = device(report)
      tools = nozzle_list(dev, print).each_with_index.map { |entry, index| tool(entry, index, print, dev) }
      assign_material(tools, material)
    end

    def self.bed(report)
      print = print_hash(report)
      raw = print['bed_temper']
      raw ||= device(report).dig('bed', 'info', 'temp') || device(report).dig('bed', 'temp')
      celsius(raw)
    end

    def self.chamber(report, model:)
      return nil unless Models.chamber?(model)

      print = print_hash(report)
      raw = device(report).dig('ctc', 'info', 'temp') || device(report).dig('ctc', 'temp') || print['chamber_temper']
      value = celsius(raw)
      return nil if value.nil? || value <= 0 || value > 120

      value
    end

    def self.number(value)
      return nil if value.nil? || value.to_s.strip.empty?

      Float(value)
    rescue ArgumentError, TypeError
      nil
    end

    def self.device(report)
      report['device'] || report.dig('print', 'device') || {}
    end

    def self.print_hash(report)
      report['print'].is_a?(Hash) ? report['print'] : {}
    end

    def self.celsius(value)
      reading = number(value)
      return nil if reading.nil?
      return reading if reading.abs <= DEGREE_LIMIT

      (reading.to_i & 0xFFFF).to_f
    end

    def self.nozzle_list(device, print)
      extruders = entries_of(device['extruder'])
      return extruders if extruders.any?

      nozzles = entries_of(device['nozzle'])
      return nozzles if nozzles.any?

      [{ 'temp' => print['nozzle_temper'], 'diameter' => print['nozzle_diameter'], 'type' => print['nozzle_type'] }]
    end

    # device.nozzle is a hash ({info: [...]}) on P2S and an array on older guesses.
    def self.entries_of(node)
      node = node['info'] if node.is_a?(Hash)
      return [] unless node.is_a?(Array)

      node.grep(Hash)
    end

    def self.tool(entry, index, print, device)
      {
        'index' => index,
        'temp' => tool_temp(entry, print),
        'nozzle_diameter' => number(entry['diameter'] || entry['nozzle_diameter'] || nozzle_spec(device)['diameter'] ||
                                    print['nozzle_diameter']),
        'high_flow' => high_flow?(entry, print, device)
      }
    end

    def self.tool_temp(entry, print)
      own = entry['temp'] || entry['temperature'] || entry['nozzle_temper'] || entry['nozzle_temp']
      degrees_or_nil(own) || degrees_or_nil(print['nozzle_temper']) || celsius(own || print['nozzle_temper'])
    end

    def self.degrees_or_nil(value)
      return nil if value.nil? || packed?(value)

      celsius(value)
    end

    def self.packed?(value)
      reading = number(value)
      reading.present? && reading.abs > DEGREE_LIMIT
    end

    def self.nozzle_spec(device)
      entries_of(device['nozzle']).first || {}
    end

    def self.assign_material(tools, material)
      return tools if material.blank?

      hot = tools.index { |tool| tool['temp'].to_f > 40 } || 0
      tools.each_with_index.map { |tool, index| tool.merge('material' => index == hot ? material : nil) }
    end

    def self.high_flow?(entry, print, device)
      type = (entry['type'] || entry['nozzle_type'] || nozzle_spec(device)['type'] || print['nozzle_type']).to_s
      type.match?(/high[\s_-]?flow|\bhf\b/i)
    end
  end
end
