module BambuLan
  # MQTT `project_file` fields for a .3mf that was just uploaded to /cache.
  # A single-color print uses the external spool when that's what the printer
  # has selected, and otherwise the tray that is selected. Multi-color prints
  # need one loaded AMS tray per filament, in tray order.
  class ProjectFile
    def self.fields(filename:, archive:, report:)
      new(filename, archive, report).fields
    end

    def initialize(filename, archive, report)
      @filename = filename
      @archive = archive
      @print = report['print'].is_a?(Hash) ? report['print'] : {}
    end

    def fields
      base.merge(ams_fields)
    end

    private

    def base
      {
        'param' => "Metadata/#{plate}",
        'project_id' => '0',
        'profile_id' => '0',
        'task_id' => '0',
        'subtask_id' => '0',
        'subtask_name' => subtask_name,
        'file' => '',
        'url' => "ftp:///cache/#{@filename}",
        'md5' => '',
        'timelapse' => false,
        'bed_type' => 'auto',
        'bed_levelling' => true,
        'flow_cali' => false,
        'vibration_cali' => false,
        'layer_inspect' => false
      }
    end

    def plate
      @archive&.plate.presence || 'plate_1.gcode'
    end

    def subtask_name
      File.basename(@filename, File.extname(@filename.to_s)).sub(/\.gcode\z/i, '').slice(0, 60)
    end

    def ams_fields
      count = [@archive&.filament_count.to_i, 1].max
      trays = Materials.loaded_indexes(@print)
      return external if count == 1 && (trays.empty? || Materials.external?(@print))
      raise Error, filament_message(count, trays.size) if trays.size < count

      { 'use_ams' => true, 'ams_mapping' => mapping(count, trays) }
    end

    def mapping(count, trays)
      return [single_tray(trays)] if count == 1

      trays.first(count)
    end

    def single_tray(trays)
      current = Materials.current_index(@print)
      return current if current && trays.include?(current)

      trays.first
    end

    def external
      { 'use_ams' => false, 'ams_mapping' => '' }
    end

    def filament_message(needed, loaded)
      "This file needs #{needed} filaments and the AMS has #{loaded} loaded."
    end
  end
end
