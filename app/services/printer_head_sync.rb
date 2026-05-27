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
    head.nozzle_size_mm = entry.nozzle_size_mm if entry.nozzle_size_mm.present?
    head.material = entry.material if entry.material.present?
    head.high_flow = entry.high_flow
    head.save!
  end
end
