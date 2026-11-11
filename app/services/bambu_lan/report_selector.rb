module BambuLan
  # A pushall answer is a full snapshot (`print.msg == 0`). Later messages on
  # the same connection are deltas and must not replace the snapshot.
  module ReportSelector
    def self.snapshot?(message)
      print = message['print']
      return false unless usable?(print)

      print['msg'].to_s == '0'
    end

    def self.better(current, message)
      print = message['print']
      return current unless usable?(print)
      return message if current.nil? || print.size > current.fetch('print', {}).size

      current
    end

    def self.usable?(print)
      print.is_a?(Hash) && print['gcode_state'].present? && print['result'].blank?
    end
  end
end
