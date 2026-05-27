class DashboardPresenter
  Card = Struct.new(:printer, :current_job, :heads, :snapshot, keyword_init: true) do
    def printing?
      current_job&.active?
    end

    def preview_attached?
      current_job&.preview_image&.attached?
    end

    def head_labels
      heads.map(&:label).join(' · ')
    end

    def snapshot_attached?
      snapshot&.image&.attached?
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
      snapshot: latest_snapshot(printer, job)
    )
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
