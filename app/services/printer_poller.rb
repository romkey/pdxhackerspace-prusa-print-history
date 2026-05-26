class PrinterPoller
  PRUSA_TO_STATUS = {
    'PRINTING' => 'printing',
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
    job_payload    = safe_job_payload
    mapped_status  = map_status(status_payload)

    if idle_state?(status_payload)
      finalize_active_jobs!
      update_printer_environment!(operational_state: 'idle')
      return
    end

    job = upsert_job(job_payload, mapped_status)
    update_printer_environment!(operational_state: mapped_status || 'unknown')
    return if job.nil?

    record_telemetry(job, status_payload)
    detect_status_change(job, mapped_status)
    finalize_if_terminal(job, job_payload)
  rescue PrusaLink::Error => e
    Rails.logger.warn("PrinterPoller failed for printer ##{@printer.id}: #{e.message}")
  end

  private

  def safe_job_payload
    @prusalink.job
  rescue PrusaLink::Error
    nil
  end

  def map_status(status_payload)
    raw = status_payload.dig('printer', 'state') || status_payload['state']
    PRUSA_TO_STATUS.fetch(raw.to_s.upcase, raw&.downcase)
  end

  def idle_state?(status_payload)
    raw = (status_payload.dig('printer', 'state') || status_payload['state']).to_s.upcase
    IDLE_STATES.include?(raw)
  end

  def finalize_active_jobs!
    @printer.jobs.active.find_each do |job|
      from_status = job.status
      job.update!(status: 'finished', ended_at: Time.current)
      job.events.create!(
        event_type: 'finished',
        from_status: from_status,
        to_status: 'finished',
        occurred_at: Time.current
      )
    end
  end

  def update_printer_environment!(operational_state:)
    @printer.update!(
      operational_state: operational_state,
      ambient_temp: sensor_value(Setting.default_ambient_sensor),
      enclosure_temp: sensor_value(@printer.enclosure_temp_sensor),
      enclosure_humidity: sensor_value(@printer.humidity_sensor),
      environment_updated_at: Time.current
    )
  end

  def upsert_job(job_payload, status)
    return nil if job_payload.blank?

    job = find_or_initialize_job(job_payload)
    job.filename     = extract_filename(job_payload) || job.filename
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
      job_payload['filename']
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

    CaptureEventPhotoJob.perform_later(event.id) if @printer.camera?
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
