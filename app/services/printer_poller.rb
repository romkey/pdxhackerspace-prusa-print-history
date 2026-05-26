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
    job_payload    = resolve_job_payload(status_payload)
    mapped_status  = map_status(status_payload)

    return handle_idle_poll(status_payload) if idle_state?(status_payload)
    return handle_terminal_without_job(mapped_status, status_payload) if terminal_without_job?(
      mapped_status, job_payload
    )

    handle_job_poll(status_payload, job_payload, mapped_status)
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

  def handle_job_poll(status_payload, job_payload, mapped_status)
    job = upsert_job(job_payload, mapped_status)
    job ||= ensure_active_job!(mapped_status, job_payload, status_payload)
    update_printer_environment!(operational_state: mapped_status || 'unknown')

    if job.nil?
      broadcast_live_update
      return
    end

    record_telemetry(job, status_payload)
    PrinterToolSync.sync!(job, status_payload, job_payload)
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
      job.update!(status: status, ended_at: Time.current)
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
      ambient_temp: sensor_value(Setting.default_ambient_sensor),
      enclosure_temp: sensor_value(@printer.enclosure_temp_sensor),
      enclosure_humidity: sensor_value(@printer.humidity_sensor),
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
      enclosure_temp: sensor_value(@printer.enclosure_temp_sensor),
      ambient_temp: sensor_value(Setting.default_ambient_sensor),
      enclosure_humidity: sensor_value(@printer.humidity_sensor)
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

  def sensor_value(entity_id)
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
      total_filament_grams: job_payload&.dig('file', 'meta', 'filament used [g]')
    )
  end
end
# rubocop:enable Metrics/ClassLength
