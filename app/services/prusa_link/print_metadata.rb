module PrusaLink
  # Normalizes nozzle/material/high-flow data from every PrusaLink source we know about.
  # rubocop:disable Metrics/ModuleLength
  module PrintMetadata
    DEFAULT_NOZZLE_MM = 0.4

    MATERIAL_KEYS = ['filament_type', 'filament type', 'material_name'].freeze
    NOZZLE_KEYS = ['nozzle_diameter', 'nozzle diameter'].freeze
    HIGH_FLOW_KEYS = ['nozzle_high_flow', 'nozzle high flow', 'high flow'].freeze
    MATERIAL_ARRAY_KEYS = ['filament_type per tool', 'filament type per tool'].freeze
    NOZZLE_ARRAY_KEYS = ['nozzle_diameter per tool', 'nozzle diameter per tool'].freeze
    HIGH_FLOW_ARRAY_KEYS = ['nozzle_high_flow per tool', 'high flow per tool'].freeze

    ToolEntry = Struct.new(:tool_index, :nozzle_size_mm, :material, :high_flow, keyword_init: true)

    module_function

    def tool_entries(status_payload: {}, job_payload: nil, info_payload: {}, legacy_payload: {},
                     file_meta: nil)
      meta = file_meta.presence || job_payload&.dig('file', 'meta') || {}
      indices = collect_indices(status_payload, meta, info_payload: info_payload)

      entries = indices.map do |tool_index|
        merge_entry(
          tool_index,
          legacy: from_legacy(legacy_payload, tool_index),
          info: from_info(info_payload, tool_index),
          status: from_status_tool(status_payload, tool_index),
          meta: from_meta(meta, tool_index)
        )
      end

      apply_loaded_filament_from_legacy(entries, legacy_payload)
    end

    def legacy_telemetry_material(legacy_payload)
      return nil if legacy_payload.blank?

      string(
        legacy_payload.dig('telemetry', 'material') ||
        legacy_payload.dig('printer', 'telemetry', 'material')
      )
    end

    def apply_loaded_filament_from_legacy(entries, legacy_payload)
      material = legacy_telemetry_material(legacy_payload)
      return entries if material.blank?

      remaining = entries.reject { |entry| entry.tool_index.zero? }
      existing = entries.find { |entry| entry.tool_index.zero? }

      remaining << ToolEntry.new(
        tool_index: 0,
        nozzle_size_mm: existing&.nozzle_size_mm || DEFAULT_NOZZLE_MM,
        material: material,
        high_flow: existing&.high_flow == true
      )

      remaining.sort_by(&:tool_index)
    end

    def collect_indices(status_payload, meta, info_payload: {})
      indices = status_tools(status_payload).map.with_index { |tool, index| tool_index(tool, index) }
      indices.concat(Array.new(meta_tool_count(meta)) { |i| i })
      indices.concat(info_tool_indices(info_payload))
      indices << 0
      indices.uniq.sort
    end

    def merge_entry(tool_index, legacy:, info:, status:, meta:)
      nozzle = [info, status, meta, legacy].filter_map { |source| source[:nozzle_size_mm] }.first
      material = [legacy, info, status, meta].filter_map { |source| source[:material] }
                                             .find { |value| meaningful_material?(value) }
      high_flow = [info, status, meta, legacy].filter_map { |source| source[:high_flow] }
                                              .find { |value| !value.nil? }

      ToolEntry.new(
        tool_index: tool_index,
        nozzle_size_mm: nozzle || DEFAULT_NOZZLE_MM,
        material: material,
        high_flow: high_flow == true
      )
    end

    def from_meta(meta, tool_index)
      {
        nozzle_size_mm: numeric(meta_value(meta, NOZZLE_KEYS, tool_index)),
        material: string(meta_value(meta, MATERIAL_KEYS, tool_index)) ||
          string(filament_from_list(meta['printing_filament_types'], tool_index)),
        high_flow: boolean(meta_value(meta, HIGH_FLOW_KEYS, tool_index))
      }
    end

    def from_status_tool(status_payload, tool_index)
      tool = status_tools(status_payload).each_with_index.find do |entry, index|
        tool_index(entry, index) == tool_index
      end&.first
      return {} if tool.blank?

      {
        nozzle_size_mm: numeric(tool['nozzle_diameter'] || tool['nozzle_diameter_mm']),
        material: string(tool['material'] || tool['filament_type']),
        high_flow: boolean(tool['high_flow'] || tool['nozzle_high_flow'])
      }
    end

    def from_legacy(legacy_payload, tool_index)
      return {} unless tool_index.zero?

      material = legacy_telemetry_material(legacy_payload)
      return {} if material.blank?

      { material: material }
    end

    def from_info(info_payload, tool_index)
      tools = info_payload['tools']
      if tools.is_a?(Hash)
        slot = info_tool_slot(tools, tool_index)
        return slot_entry(slot) if slot.present?
      end

      return {} unless tool_index.zero?

      { nozzle_size_mm: numeric(info_payload['nozzle_diameter']) }
    end

    def info_tool_slot(tools, tool_index)
      tools[(tool_index + 1).to_s] ||
        tools[tool_index.to_s] ||
        tools[(tool_index + 1).to_s.to_sym] ||
        tools[tool_index.to_s.to_sym]
    end

    def info_tool_indices(info_payload)
      tools = info_payload['tools']
      return [] unless tools.is_a?(Hash)

      tools.keys.filter_map do |key|
        index = key.to_i
        next if index.negative?

        index.positive? ? index - 1 : index
      end
    end

    def filament_from_list(raw, tool_index)
      return nil if raw.blank?

      parts = raw.is_a?(Array) ? raw : raw.to_s.split(',').map(&:strip)
      parts[tool_index]
    end

    def slot_entry(slot)
      {
        nozzle_size_mm: numeric(slot['nozzle_diameter']),
        material: meaningful_material?(slot['material']) ? string(slot['material']) : nil,
        high_flow: boolean(slot['high_flow'])
      }
    end

    def status_tools(status_payload)
      status_payload['tools'] || status_payload.dig('printer', 'tools') || []
    end

    def tool_index(tool_data, index)
      (tool_data['index'] || index).to_i
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def meta_tool_count(meta)
      return 0 if meta.blank?

      array_sizes = (MATERIAL_ARRAY_KEYS + NOZZLE_ARRAY_KEYS).filter_map do |key|
        value = meta[key]
        value.is_a?(Array) ? value.size : nil
      end

      suffix_indices = meta.keys.filter_map do |key|
        if (bracket = key[/\[(\d+)\]/, 1])
          bracket.to_i
        else
          match = key[/ (\d+)\z/, 1]&.to_i
          match&.positive? ? match - 1 : nil
        end
      end

      list_count = filament_list_count(meta['printing_filament_types'])

      [array_sizes.max || 0, suffix_indices.max.to_i + 1, list_count, 0].max
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def filament_list_count(raw)
      return 0 if raw.blank?

      parts = raw.is_a?(Array) ? raw : raw.to_s.split(',').map(&:strip)
      parts.size
    end

    def meta_value(meta, bases, tool_index)
      array_value = meta_array_value(meta, bases, tool_index)
      return array_value if array_value.present?

      suffix_value(meta, bases, tool_index)
    end

    def meta_array_value(meta, bases, tool_index)
      array_keys_for(bases).each do |key|
        value = meta[key]
        return value[tool_index] if value.is_a?(Array) && value[tool_index].present?
      end

      nil
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def suffix_value(meta, bases, tool_index)
      suffixes = [tool_index.zero? ? '' : " #{tool_index + 1}", "[#{tool_index}]"]
      suffixes.each do |suffix|
        bases.each do |base|
          keyed = meta["#{base}#{suffix}"]
          return keyed if keyed.present?

          next unless tool_index.zero? && suffix.empty?

          fallback = meta[base]
          return fallback if fallback.present?
        end
      end

      nil
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def array_keys_for(bases)
      case bases
      when MATERIAL_KEYS then MATERIAL_ARRAY_KEYS
      when NOZZLE_KEYS then NOZZLE_ARRAY_KEYS
      when HIGH_FLOW_KEYS then HIGH_FLOW_ARRAY_KEYS
      else []
      end
    end

    def numeric(value)
      return nil if value.blank?

      value.to_f
    end

    def string(value)
      value = value.to_s.strip
      value.presence
    end

    def boolean(value)
      return nil if value.nil?

      ActiveModel::Type::Boolean.new.cast(value)
    end

    def meaningful_material?(value)
      string = string(value)
      string.present? && string != '---'
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
