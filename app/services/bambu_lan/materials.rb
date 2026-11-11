module BambuLan
  # AMS tray indexing matches the printer: global index is (ams_id * 4) + tray_id.
  # 254 and 255 both mean the external spool.
  module Materials
    EXTERNAL = %w[254 255].freeze

    def self.loaded_type(print)
      tray = current_tray(print)
      type = tray && tray['tray_type'].to_s.strip
      return type if type.present?

      print.dig('vt_tray', 'tray_type').to_s.strip.presence
    end

    def self.external?(print)
      now = print.dig('ams', 'tray_now')
      now.nil? || now.to_s.strip.empty? || EXTERNAL.include?(now.to_s)
    end

    def self.current_index(print)
      return nil if external?(print)

      print.dig('ams', 'tray_now').to_i
    end

    def self.loaded_indexes(print)
      indexes = []
      Array(print.dig('ams', 'ams')).each do |unit|
        Array(unit['tray']).each do |tray|
          next if tray['tray_type'].to_s.strip.empty?

          indexes << ((unit['id'].to_i * 4) + tray['id'].to_i)
        end
      end
      indexes.uniq.sort
    end

    def self.current_tray(print)
      return nil if external?(print)

      find_tray(print, current_index(print))
    end

    def self.find_tray(print, index)
      Array(print.dig('ams', 'ams')).each do |unit|
        Array(unit['tray']).each do |tray|
          return tray if ((unit['id'].to_i * 4) + tray['id'].to_i) == index
        end
      end
      nil
    end
  end
end
