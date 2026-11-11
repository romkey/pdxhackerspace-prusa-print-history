require 'rexml/document'
require 'zip'

module BambuLan
  # Reads a sliced .3mf (a zip): plate gcode name, filament weight, and the plate thumbnail.
  class Archive
    Result = Data.define(:plate, :grams, :png, :filament_count)
    MAX_ENTRY = 8 * 1024 * 1024

    def self.read(io)
      parse(io.read)
    end

    def self.parse(bytes)
      return nil if bytes.blank?

      # open_buffer returns the buffer, not the block value.
      parsed = nil
      Zip::File.open_buffer(bytes) { |zip| parsed = from_zip(zip) }
      parsed
    rescue Zip::Error
      nil
    end

    def self.from_zip(zip)
      plate = plate_name(zip)
      number = plate[/\d+/] || '1'
      Result.new(
        plate: plate,
        grams: grams_for(zip, number),
        png: preview_png(zip, number),
        filament_count: filament_count(zip, number)
      )
    end

    def self.plate_name(zip)
      match = zip.entries.map { |entry| normalize(entry.name) }.grep(%r{\AMetadata/plate_\d+\.gcode\z}).min
      File.basename(match || 'Metadata/plate_1.gcode')
    end

    def self.preview_png(zip, number)
      ["Metadata/plate_#{number}.png", "Metadata/plate_#{number}_small.png",
       "Metadata/top_#{number}.png"].each do |name|
        bytes = read_entry(zip, name)
        return bytes if bytes.present?
      end
      nil
    end

    def self.grams_for(zip, number)
      plate = plate_node(zip, number)
      return nil if plate.nil?

      used = REXML::XPath.match(plate, './/filament').filter_map { |node| float_attr(node, 'used_g') }
      return used.sum if used.any?

      weight = metadata(plate, 'weight')
      Float(weight) if weight.present?
    rescue ArgumentError, REXML::ParseException
      nil
    end

    def self.filament_count(zip, number)
      plate = plate_node(zip, number)
      return 1 if plate.nil?

      count = REXML::XPath.match(plate, './/filament').count { |node| filament_node?(node) }
      count.positive? ? count : 1
    rescue REXML::ParseException
      1
    end

    def self.plate_node(zip, number)
      xml = read_entry(zip, 'Metadata/slice_info.config')
      return nil if xml.blank?

      plates = REXML::XPath.match(REXML::Document.new(xml), '//plate')
      plates.find { |node| metadata(node, 'index').to_s == number.to_s } || plates.first
    rescue REXML::ParseException
      nil
    end

    def self.filament_node?(node)
      node.attributes['type'].present? || node.attributes['used_g'].present?
    end

    def self.metadata(plate, key)
      node = REXML::XPath.match(plate, './metadata').find { |item| item.attributes['key'] == key }
      node&.attributes&.[]('value')
    end

    def self.float_attr(node, name)
      raw = node.attributes[name]
      return nil if raw.blank?

      Float(raw)
    rescue ArgumentError
      nil
    end

    def self.read_entry(zip, name)
      entry = zip.entries.find { |item| normalize(item.name) == name }
      return nil if entry.nil? || entry.size.to_i > MAX_ENTRY

      zip.read(entry)
    end

    def self.normalize(name)
      name.to_s.delete_prefix('./')
    end
  end
end
