# Polls PrusaLink and Home Assistant, updates jobs, and broadcasts live UI updates.
# rubocop:disable Metrics/ClassLength
class PrinterPoller
  PRUSA_TO_STATUS = {
    'PRINTING' => 'printing',
    'BUSY' => 'printing',
    'PAUSED' => 'paused',
    'ATTENTION' => 'attention',
    'ERROR' => 'error',
    'FINISHED' => 'finished',
    'STOPPED' => 'cancelled',
    'CANCELLED' => 'cancelled',
    'IDLE' => nil,
    'READY' => nil
  }.freeze

  IDLE_STATES = %w[IDLE READY].freeze

  EVENT_TYPE_FOR_STATUS = {
    'paused' => 'paused',
    'attention' => 'attention',
    'error' => 'error',
    'finished' => 'finished',
    'cancelled' => 'cancelled'
  }.freeze

  def initialize(printer, prusalink: PrusaLink::Client.new(printer), home_assistant: HomeAssistant::Client.from_env)
    @printer = printer
    @prusalink = prusalink
    @home_assistant = home_assistant
  end

  def poll!
    return unless @printer.prusalink?

    status_payload = @prusalink.status
    record_prusalink_reachable!
    info_payload     = safe_info
    legacy_payload   = safe_legacy_printer
    job_payload      = resolve_job_payload(status_payload)
    file_meta        = resolve_file_meta(job_payload)
    head_entries     = build_head_entries(status_payload, job_payload, info_payload, legacy_payload, file_meta)
    sync_printer_heads!(head_entries)

    mapped_status = map_status(status_payload)

    return handle_idle_poll(status_payload) if idle_state?(status_payload)
    return handle_terminal_without_job(mapped_status, status_payload) if terminal_without_job?(
      mapped_status, job_payload
    )

    handle_job_poll(status_payload, job_payload, mapped_status, head_entries)
  rescue PrusaLink::Error => e
    record_prusalink_unreachable!
    broadcast_live_update
    Rails.logger.warn("PrinterPoller failed for printer ##{@printer.id}: #{e.message}")
  end

  private

  def handle_idle_poll(status_payload)
    finalize_active_jobs!(status_payload: status_payload)
    update_printer_environment!(operational_state: 'idle')
    broadcast_live_update
  end

  def handle_terminal_without_job(mapped_status, status_payload)
    finalize_active_jobs!(status: mapped_status, status_payload: status_payload)
    update_printer_environment!(operational_state: 'idle')
    broadcast_live_update
  end

  def handle_job_poll(status_payload, job_payload, mapped_status, head_entries)
    job = upsert_job(job_payload, mapped_status)
    job ||= ensure_active_job!(mapped_status, job_payload, status_payload)
    update_printer_environment!(operational_state: mapped_status || 'unknown')

    if job.nil?
      broadcast_live_update
      return
    end

    sync_job_progress!(job, job_payload, status_payload)
    record_telemetry(job, status_payload)
    PrinterToolSync.sync!(job, head_entries)
    JobImageCapture.capture_preview!(job, job_payload, client: @prusalink)
    detect_status_change(job, mapped_status)
    finalize_if_terminal(job, job_payload)
    update_printer_environment!(operational_state: 'idle') if job.reload.terminal?

    broadcast_live_update
  end

  def terminal_without_job?(mapped_status, job_payload)
    mapped_status.in?(Job::TERMINAL_STATUSES) && job_payload.blank?
  end

  def safe_job_payload
    @prusalink.job
  rescue PrusaLink::Error
    nil
  end

  def safe_info
    @prusalink.info
  rescue PrusaLink::Error
    {}
  end

  def safe_legacy_printer
    @prusalink.legacy_printer
  rescue PrusaLink::Error
    nil
  end

  def build_head_entries(status_payload, job_payload, info_payload, legacy_payload, file_meta)
    PrusaLink::PrintMetadata.tool_entries(
      status_payload: status_payload,
      job_payload: job_payload,
      info_payload: info_payload || {},
      legacy_payload: legacy_payload || {},
      file_meta: file_meta
    )
  end

  def sync_printer_heads!(head_entries)
    return if head_entries.blank?

    summary = head_entries.map do |entry|
      material = entry.material.presence || '—'
      "T#{entry.tool_index} #{entry.nozzle_size_mm}mm #{material}"
    end.join(', ')
    Rails.logger.info("[PrinterHeadSync] printer ##{@printer.id} (#{@printer.name}): #{summary}")

    PrinterHeadSync.sync!(@printer, head_entries)
  end

  def resolve_file_meta(job_payload)
    meta = job_payload&.dig('file', 'meta')
    return meta if meta.present?

    storage_path = file_storage_path(job_payload)
    return nil if storage_path.blank?

    @prusalink.file_info(storage_path)&.dig('meta')
  rescue PrusaLink::Error
    nil
  end

  def file_storage_path(job_payload)
    download = job_payload&.dig('file', 'refs', 'download')
    return download if download.present?

    dir  = job_payload&.dig('file', 'path')
    name = job_payload&.dig('file', 'name')
    return nil if dir.blank? || name.blank?

    "#{dir}/#{name}"
  end

  def resolve_job_payload(status_payload)
    payload = safe_job_payload
    return payload if payload.present?

    status_payload['job'].presence
  end

  def ensure_active_job!(mapped_status, job_payload, status_payload)
    return nil unless mapped_status.in?(Job::ACTIVE_STATUSES)

    existing = @printer.jobs.active.first
    return existing if existing

    save_active_job!(mapped_status, job_payload, status_payload)
  end

  def save_active_job!(mapped_status, job_payload, status_payload)
    stub = job_payload.presence || status_payload['job'] || {}
    job = job_for_status_stub(stub)
    job.filename = extract_filename(job_payload) || job.filename || fallback_filename(stub)
    job.status = mapped_status
    job.started_at ||= Time.current
    job.save!
    job
  end

  def job_for_status_stub(stub)
    return @printer.jobs.find_or_initialize_by(prusalink_job_id: stub['id'].to_s) if stub['id'].present?

    @printer.jobs.new
  end

  def map_status(status_payload)
    raw = status_payload.dig('printer', 'state') || status_payload['state']
    PRUSA_TO_STATUS.fetch(raw.to_s.upcase, raw&.downcase)
  end

  def idle_state?(status_payload)
    raw = (status_payload.dig('printer', 'state') || status_payload['state']).to_s.upcase
    IDLE_STATES.include?(raw)
  end

  def finalize_active_jobs!(status: 'finished', status_payload: nil)
    @printer.jobs.active.find_each do |job|
      record_telemetry(job, status_payload) if status_payload.present?
      from_status = job.status
      job.update!(
        status: status,
        ended_at: Time.current,
        progress_percent: nil,
        estimated_finish_at: nil,
        time_printing_seconds: nil
      )
      job.events.create!(
        event_type: EVENT_TYPE_FOR_STATUS.fetch(status, 'finished'),
        from_status: from_status,
        to_status: status,
        occurred_at: Time.current
      )
    end
  end

  def update_printer_environment!(operational_state:)
    return unless @printer.environment_tracking?

    @printer.update!(
      operational_state: operational_state,
      ambient_temp: temperature_sensor_value(Setting.default_ambient_sensor),
      enclosure_temp: temperature_sensor_value(@printer.enclosure_temp_sensor),
      enclosure_humidity: humidity_sensor_value(@printer.humidity_sensor),
      environment_updated_at: Time.current
    )
  end

  def record_prusalink_reachable!
    return unless @printer.connection_tracking?

    @printer.update!(prusalink_reachable: true, prusalink_checked_at: Time.current)
  end

  def record_prusalink_unreachable!
    return unless @printer.connection_tracking?

    @printer.update!(prusalink_reachable: false, prusalink_checked_at: Time.current)
  end

  def broadcast_live_update
    PrinterLiveBroadcaster.broadcast(@printer)
  end

  def upsert_job(job_payload, status)
    return nil if job_payload.blank?

    job = find_or_initialize_job(job_payload)
    job.filename     = extract_filename(job_payload) || job.filename || fallback_filename(job_payload)
    job.status       = status if status.present?
    job.started_at ||= Time.current
    job.save!
    job
  end

  def find_or_initialize_job(job_payload)
    prusalink_job_id = job_payload['id'].to_s.presence
    return @printer.jobs.find_or_initialize_by(prusalink_job_id: prusalink_job_id) if prusalink_job_id

    @printer.jobs.active.first || @printer.jobs.new
  end

  def extract_filename(job_payload)
    job_payload.dig('file', 'display_name') ||
      job_payload.dig('file', 'name') ||
      job_payload['filename'] ||
      job_payload['display_name']
  end

  def fallback_filename(job_payload)
    id = job_payload['id']
    id.present? ? "Print job #{id}" : 'Active print'
  end

  def record_telemetry(job, status_payload)
    job.telemetry_readings.create!(
      recorded_at: Time.current,
      tool_temps: extract_tool_temps(status_payload),
      bed_temp: bed_temp(status_payload),
      enclosure_temp: temperature_sensor_value(@printer.enclosure_temp_sensor),
      ambient_temp: temperature_sensor_value(Setting.default_ambient_sensor),
      enclosure_humidity: humidity_sensor_value(@printer.humidity_sensor)
    )
  end

  def bed_temp(status_payload)
    status_payload.dig('printer', 'temp_bed') || status_payload.dig('telemetry', 'temp-bed')
  end

  def extract_tool_temps(status_payload)
    tools = status_payload['tools'] || status_payload.dig('printer', 'tools') || []
    return { '0' => status_payload.dig('printer', 'temp_nozzle') } if tools.empty?

    tools.each_with_index.to_h do |tool, index|
      key = (tool['index'] || index).to_s
      [key, tool['temp'] || tool['target_temp']]
    end
  end

  def temperature_sensor_value(entity_id)
    return nil if entity_id.blank?

    @home_assistant.temperature_celsius(entity_id)
  end

  def humidity_sensor_value(entity_id)
    return nil if entity_id.blank?

    @home_assistant.numeric_state(entity_id)
  end

  def detect_status_change(job, new_status)
    last_status = job.events.recent.first&.to_status
    return if new_status.blank? || new_status == last_status

    event = job.events.create!(
      event_type: event_type_for(new_status, last_status),
      from_status: last_status,
      to_status: new_status,
      occurred_at: Time.current
    )

    CaptureEventPhotoJob.perform_later(event.id) if @printer.camera_configured?
  end

  def event_type_for(new_status, last_status)
    return 'started' if last_status.nil? && new_status == 'printing'
    return 'resumed' if new_status == 'printing' && last_status == 'paused'

    EVENT_TYPE_FOR_STATUS.fetch(new_status, 'status_changed')
  end

  def finalize_if_terminal(job, job_payload)
    return unless Job::TERMINAL_STATUSES.include?(job.status)
    return if job.ended_at.present?

    job.update!(
      ended_at: Time.current,
      total_duration_seconds: (job_payload && job_payload['time_printing'].presence) || job.duration_seconds,
      total_filament_grams: filament_grams_from_meta(job_payload),
      progress_percent: nil,
      estimated_finish_at: nil,
      time_printing_seconds: nil
    )
  end

  def sync_job_progress!(job, job_payload, status_payload)
    telemetry = job_status_data(job_payload, status_payload)
    return if telemetry.blank?

    attrs = {}
    attrs[:progress_percent] = telemetry['progress'].to_f unless telemetry['progress'].nil?
    unless telemetry['time_remaining'].nil?
      attrs[:estimated_finish_at] = Time.current + telemetry['time_remaining'].to_i.seconds
    end
    attrs[:time_printing_seconds] = telemetry['time_printing'].to_i unless telemetry['time_printing'].nil?

    job.update!(attrs) if attrs.any?
  end

  def job_status_data(job_payload, status_payload)
    status_job = status_payload['job'] || {}
    payload = job_payload || {}

    %w[progress time_remaining time_printing].each_with_object({}) do |key, data|
      value = payload.key?(key) ? payload[key] : status_job[key]
      data[key] = value unless value.nil?
    end
  end

  def filament_grams_from_meta(job_payload)
    meta = job_payload&.dig('file', 'meta') || {}
    meta['filament used [g]'] || meta['filament_used_g']
  end
end
# rubocop:enable Metrics/ClassLength
