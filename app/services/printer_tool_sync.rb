class PrinterToolSync
  DEFAULT_NOZZLE_MM = 0.4

  def self.sync!(job, status_payload, job_payload)
    new(job, status_payload, job_payload).sync!
  end

  def initialize(job, status_payload, job_payload)
    @job = job
    @status_payload = status_payload
    @job_payload = job_payload
  end

  def sync!
    tool_entries = @status_payload['tools'] || @status_payload.dig('printer', 'tools') || []
    if tool_entries.empty?
      sync_default_tool!
      return
    end

    tool_entries.each_with_index { |tool_data, index| upsert_tool!(tool_data, index) }
  end

  private

  def upsert_tool!(tool_data, index)
    tool_index = (tool_data['index'] || index).to_i
    meta = tool_meta(tool_index)
    tool = @job.tools.find_or_initialize_by(tool_index: tool_index)
    tool.nozzle_size_mm = meta[:nozzle_size_mm] || tool.nozzle_size_mm || DEFAULT_NOZZLE_MM
    tool.material = meta[:material] if meta[:material].present?
    tool.high_flow = meta[:high_flow] unless meta[:high_flow].nil?
    tool.save!
  end

  def sync_default_tool!
    return if @status_payload.dig('printer', 'temp_nozzle').blank?

    tool = @job.tools.find_or_initialize_by(tool_index: 0)
    tool.nozzle_size_mm ||= DEFAULT_NOZZLE_MM
    tool.save!
  end

  def tool_meta(tool_index)
    meta = @job_payload&.dig('file', 'meta') || {}
    suffix = tool_index.zero? ? '' : " #{tool_index + 1}"

    {
      nozzle_size_mm: meta["nozzle diameter#{suffix}"] || meta['nozzle diameter'],
      material: meta["filament type#{suffix}"] || meta['filament type'],
      high_flow: optional_boolean(meta["high flow#{suffix}"] || meta['high flow'])
    }
  end

  def optional_boolean(value)
    value.nil? ? nil : ActiveModel::Type::Boolean.new.cast(value)
  end
end
