class PrinterToolSync
  def self.sync!(job, entries)
    new(job, entries).sync!
  end

  def initialize(job, entries)
    @job = job
    @entries = entries
  end

  def sync!
    @entries.each { |entry| upsert_tool!(entry) }
  end

  private

  def upsert_tool!(entry)
    tool = @job.tools.find_or_initialize_by(tool_index: entry.tool_index)
    tool.nozzle_size_mm = entry.nozzle_size_mm if entry.nozzle_size_mm.present?
    tool.material = entry.material if entry.material.present?
    tool.high_flow = entry.high_flow
    tool.save!
  end
end
