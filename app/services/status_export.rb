# rubocop:disable Metrics/ModuleLength
module StatusExport
  RECENT_JOBS_LIMIT = 100
  RECENT_EVENTS_LIMIT = 100

  module_function

  def printers(include_email: true)
    records = Printer.ordered.includes(:printer_heads)
    active_jobs = Job.active
                     .where(printer_id: records.map(&:id))
                     .includes(:owner, :cleared_by, :tools, preview_image_attachment: :blob)
    active_by_printer = active_jobs.index_by(&:printer_id)

    records.map do |printer|
      printer_as_json(printer, job: active_by_printer[printer.id], include_email: include_email)
    end
  end

  def jobs(limit: RECENT_JOBS_LIMIT, include_email: true)
    Job.recent
       .includes(:printer, :owner, :cleared_by, :tools)
       .limit(limit)
       .map { |job| job_as_json(job, include_printer: true, include_email: include_email) }
  end

  def events(limit: RECENT_EVENTS_LIMIT, include_email: true)
    JobEvent.recent
            .includes(job: %i[printer owner tools])
            .limit(limit)
            .map { |event| event_as_json(event, include_email: include_email) }
  end

  def printer_as_json(printer, job:, include_email: true)
    printer_attributes(printer).merge(
      snapshot_url: snapshot_url(printer),
      preview_url: preview_url(printer, job),
      heads: printer.printer_heads.sort_by(&:tool_index).map { |head| head_as_json(head) },
      job: job ? job_as_json(job, include_email: include_email) : nil
    )
  end

  def snapshot_url(printer)
    return nil unless printer.camera_configured?

    url_helpers.camera_printer_path(printer)
  end

  def preview_url(printer, active_job)
    job = active_job if job_preview_attached?(active_job)
    job ||= latest_preview_job(printer)
    return nil unless job_preview_attached?(job)

    url_helpers.rails_blob_path(job.preview_image, only_path: true)
  end

  def job_preview_attached?(job)
    job.present? && job.preview_image.attached?
  end

  def latest_preview_job(printer)
    printer.jobs.joins(:preview_image_attachment).reorder(created_at: :desc).first
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end

  def printer_attributes(printer)
    printer_identity_attributes(printer)
      .merge(printer_environment_attributes(printer))
      .merge(printer_connectivity_attributes(printer))
  end

  def printer_identity_attributes(printer)
    {
      id: printer.id,
      name: printer.name,
      location: printer.location,
      model: printer.model,
      hostname: printer.hostname,
      camera_url: printer.camera_url,
      ha_base_sensor: printer.ha_base_sensor,
      enclosure_temp_sensor: printer.enclosure_temp_sensor,
      humidity_sensor: printer.humidity_sensor,
      camera: printer.camera?,
      camera_configured: printer.camera_configured?,
      prusalink: printer.prusalink?,
      home_assistant: printer.home_assistant?,
      created_at: timestamp(printer.created_at),
      updated_at: timestamp(printer.updated_at)
    }
  end

  def printer_environment_attributes(printer)
    {
      ambient_temp: decimal(printer.ambient_temp),
      enclosure_temp: decimal(printer.enclosure_temp),
      enclosure_humidity: decimal(printer.enclosure_humidity),
      environment_updated_at: timestamp(printer.environment_updated_at),
      operational_state: printer.operational_state
    }
  end

  def printer_connectivity_attributes(printer)
    {
      prusalink_reachable: printer.prusalink_reachable,
      prusalink_checked_at: timestamp(printer.prusalink_checked_at),
      display_status: printer.display_status,
      prusalink_connection_status: printer.prusalink_connection_status.to_s
    }
  end

  def job_as_json(job, include_printer: false, include_email: true)
    payload = job_attributes(job, include_email: include_email)
    payload[:printer] = printer_summary_as_json(job.printer) if include_printer
    payload
  end

  def job_attributes(job, include_email: true)
    job_core_attributes(job)
      .merge(job_timing_attributes(job))
      .merge(job_clearance_attributes(job))
      .merge(
        owner: user_as_json(job.owner, include_email: include_email),
        cleared_by: user_as_json(job.cleared_by, include_email: include_email),
        tools: job.tools.sort_by(&:tool_index).map { |tool| tool_as_json(tool) }
      )
  end

  def job_core_attributes(job)
    {
      id: job.id,
      printer_id: job.printer_id,
      filename: job.filename,
      status: job.status,
      progress_percent: decimal(job.progress_percent),
      prusalink_job_id: job.prusalink_job_id,
      total_filament_grams: decimal(job.total_filament_grams),
      created_at: timestamp(job.created_at),
      updated_at: timestamp(job.updated_at)
    }
  end

  def job_timing_attributes(job)
    {
      started_at: timestamp(job.started_at),
      ended_at: timestamp(job.ended_at),
      estimated_finish_at: timestamp(job.estimated_finish_at),
      time_printing_seconds: job.time_printing_seconds,
      total_duration_seconds: job.total_duration_seconds,
      duration_seconds: job.duration_seconds
    }
  end

  def job_clearance_attributes(job)
    {
      cleared_at: timestamp(job.cleared_at),
      clear_outcome: job.clear_outcome,
      clear_failure_reason: job.clear_failure_reason,
      clear_failure_detail: job.clear_failure_detail
    }
  end

  def event_as_json(event, include_email: true)
    {
      id: event.id,
      event_type: event.event_type,
      from_status: event.from_status,
      to_status: event.to_status,
      message: event.message,
      occurred_at: timestamp(event.occurred_at),
      created_at: timestamp(event.created_at),
      updated_at: timestamp(event.updated_at),
      job: job_as_json(event.job, include_email: include_email)
    }
  end

  def printer_summary_as_json(printer)
    {
      id: printer.id,
      name: printer.name,
      location: printer.location,
      model: printer.model,
      display_status: printer.display_status,
      prusalink_connection_status: printer.prusalink_connection_status.to_s
    }
  end

  def head_as_json(head)
    {
      tool_index: head.tool_index,
      nozzle_size_mm: decimal(head.nozzle_size_mm),
      high_flow: head.high_flow,
      material: head.material,
      label: head.label
    }
  end

  def tool_as_json(tool)
    {
      tool_index: tool.tool_index,
      nozzle_size_mm: decimal(tool.nozzle_size_mm),
      high_flow: tool.high_flow,
      material: tool.material,
      label: tool.label
    }
  end

  def user_as_json(user, include_email: true)
    return nil unless user

    payload = {
      id: user.id,
      name: user.name,
      username: user.username,
      display_name: user.display_name
    }
    payload[:email] = user.email if include_email
    payload
  end

  def decimal(value)
    return nil if value.nil?

    value.to_f
  end

  def timestamp(value)
    value&.iso8601(3)
  end
  private_class_method :decimal, :timestamp, :user_as_json, :head_as_json, :tool_as_json,
                       :printer_as_json, :printer_attributes, :printer_identity_attributes,
                       :printer_environment_attributes, :printer_connectivity_attributes,
                       :snapshot_url, :preview_url, :job_preview_attached?, :latest_preview_job, :url_helpers,
                       :job_as_json, :job_attributes, :job_core_attributes, :job_timing_attributes,
                       :job_clearance_attributes, :event_as_json, :printer_summary_as_json
end
# rubocop:enable Metrics/ModuleLength
