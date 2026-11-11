module BambuLan
  # Nozzle, bed, and chamber readings. Classic firmware puts them on `print`;
  # P2S and newer put nozzles on `device.nozzle` and the chamber on `device.ctc`.
  module Tools
    def self.entries(report, material:)
      list = nozzle_list(device(report), print_hash(report))
      tools = list.each_with_index.map { |entry, index| tool(entry, index, print_hash(report)) }
      assign_material(tools, material)
    end

    def self.bed(report)
      print = print_hash(report)
      number(print['bed_temper'] || device(report).dig('bed', 'temp') || device(report).dig('bed', 'bed_temper'))
    end

    def self.chamber(report, model:)
      return nil unless Models.chamber?(model)

      print = print_hash(report)
      raw = device(report).dig('ctc', 'info', 'temp') || device(report).dig('ctc', 'temp') || print['chamber_temper']
      value = number(raw)
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

    def self.nozzle_list(device, print)
      nozzles = device['nozzle']
      return nozzles if nozzles.is_a?(Array) && nozzles.any?

      extruders = device['extruder']
      extruders = extruders['info'] if extruders.is_a?(Hash)
      return extruders if extruders.is_a?(Array) && extruders.any?

      [{ 'temp' => print['nozzle_temper'], 'diameter' => print['nozzle_diameter'], 'type' => print['nozzle_type'] }]
    end

    def self.tool(entry, index, print)
      {
        'index' => index,
        'temp' => number(entry['temp'] || entry['temperature'] || entry['nozzle_temper'] || entry['nozzle_temp']),
        'nozzle_diameter' => number(entry['diameter'] || entry['nozzle_diameter'] || print['nozzle_diameter']),
        'high_flow' => high_flow?(entry, print)
      }
    end

    def self.assign_material(tools, material)
      return tools if material.blank?

      hot = tools.index { |tool| tool['temp'].to_f > 40 } || 0
      tools.each_with_index.map { |tool, index| tool.merge('material' => index == hot ? material : nil) }
    end

    def self.high_flow?(entry, print)
      type = (entry['type'] || entry['nozzle_type'] || print['nozzle_type']).to_s
      type.match?(/high[\s_-]?flow|\bhf\b/i)
    end
  end
end
