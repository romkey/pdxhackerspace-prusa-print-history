class DashboardPresenter
  Card = Struct.new(:printer, :current_job, :heads, :snapshot, :latest_reading, keyword_init: true) do
    def printing?
      current_job&.active?
    end

    def preview_attached?
      current_job&.preview_image&.attached?
    end

    def snapshot_attached?
      snapshot&.image&.attached?
    end

    def primary_head
      heads.first
    end

    def material_label
      primary_head&.material.presence || '---'
    end

    def nozzle_label
      return '---' unless primary_head

      "#{primary_head.nozzle_size_mm.to_f.round(1)}mm"
    end

    def bed_temp_c
      latest_reading&.bed_temp
    end

    def nozzle_temp_c
      latest_reading&.tool_temp(0)
    end

    def enclosure_temp_c
      latest_reading&.enclosure_temp || printer.enclosure_temp
    end

    def ambient_temp_c
      latest_reading&.ambient_temp || printer.ambient_temp
    end

    def availability_label
      case printer.prusalink_connection_status
      when :reachable then 'available'
      when :unreachable then 'unavailable'
      else 'unknown'
      end
    end

    def availability_muted?
      printer.prusalink_connection_status != :reachable
    end
  end

  attr_reader :recent_events

  def initialize(printers:, active_jobs_by_printer:, recent_events:)
    @printers = printers
    @active_jobs_by_printer = active_jobs_by_printer
    @recent_events = recent_events
  end

  def cards
    @printers.map { |printer| build_card(printer) }
  end

  def printer_count
    @printers.size
  end

  def active_job_count
    @active_jobs_by_printer.size
  end

  private

  def build_card(printer)
    job = @active_jobs_by_printer[printer.id]
    Card.new(
      printer: printer,
      current_job: job,
      heads: printer.printer_heads.sort_by(&:tool_index),
      snapshot: latest_snapshot(printer, job),
      latest_reading: latest_reading(job)
    )
  end

  def latest_reading(job)
    return nil unless job

    job.telemetry_readings.order(:recorded_at).last
  end

  def latest_snapshot(printer, job)
    if job
      job.photo_captures.progress.reverse_chronological.first ||
        printer.photo_captures.idle.reverse_chronological.first
    else
      printer.photo_captures.idle.reverse_chronological.first
    end
  end
end
