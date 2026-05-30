class PrinterHeadSync
  def self.sync!(printer, entries)
    new(printer, entries).sync!
  end

  def initialize(printer, entries)
    @printer = printer
    @entries = entries
  end

  def sync!
    @entries.each { |entry| upsert_head!(entry) }
  end

  private

  def upsert_head!(entry)
    head = @printer.printer_heads.find_or_initialize_by(tool_index: entry.tool_index)
    previous_material = head.material
    head.nozzle_size_mm = entry.nozzle_size_mm if entry.nozzle_size_mm.present?
    head.material = entry.material if entry.material.present?
    head.high_flow = entry.high_flow
    head.save!
    record_filament_change!(head, previous_material) if filament_changed?(previous_material, head.material)
  end

  def filament_changed?(previous_material, current_material)
    previous_material.present? && current_material.present? && previous_material != current_material
  end

  def record_filament_change!(head, from_material)
    @printer.printer_events.create!(
      event_type: 'filament_change',
      tool_index: head.tool_index,
      from_material: from_material,
      to_material: head.material,
      message: "T#{head.tool_index}: #{from_material} → #{head.material}",
      occurred_at: Time.current
    )
  end
end
