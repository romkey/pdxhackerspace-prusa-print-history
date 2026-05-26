class PrinterShowPresenter
  attr_reader :printer

  def initialize(printer)
    @printer = printer
  end

  delegate :current_job, to: :printer

  def display_job
    current_job || printer.jobs.recent.first
  end

  def recent_jobs
    printer.jobs.recent.includes(:owner).limit(10)
  end

  def events
    return JobEvent.none unless display_job

    display_job.events.recent.includes(photo_attachment: :blob)
  end

  def telemetry_readings
    display_job&.telemetry_readings&.ordered || TelemetryReading.none
  end

  def latest_reading
    telemetry_readings.last
  end

  def tools
    display_job&.tools&.order(:tool_index) || Tool.none
  end

  def reported_tools
    if current_job&.tools&.any?
      current_job.tools.order(:tool_index).to_a
    else
      latest_tools_from_history
    end
  end

  def latest_tools_from_history
    printer.jobs.recent.includes(:tools).detect { |job| job.tools.any? }&.tools&.sort_by(&:tool_index) || []
  end

  def chart_series
    JobTelemetryCharts.series_for(telemetry_readings.to_a)
  end

  def live_tool_temps
    latest_reading&.tool_temps || {}
  end

  def latest_photo
    if current_job
      current_job.photo_captures.progress.reverse_chronological.first ||
        printer.photo_captures.idle.reverse_chronological.first
    else
      printer.photo_captures.idle.reverse_chronological.first
    end
  end

  def camera_refresh_token
    latest_photo&.captured_at&.to_i || printer.updated_at.to_i
  end

  def locals
    {
      printer: printer,
      presenter: self
    }
  end
end
