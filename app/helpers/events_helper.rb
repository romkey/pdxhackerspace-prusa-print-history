module EventsHelper
  EVENT_FILTER_LABELS = {
    'start' => 'Start',
    'end' => 'End',
    'attention' => 'Attention',
    'filament_change' => 'Filament change'
  }.freeze

  def events_filter_href(filter_name)
    current = Array(params[:filter]).map(&:to_s)
    updated = current.include?(filter_name) ? current - [filter_name] : current + [filter_name]
    events_path(filter: updated.presence)
  end

  def events_filter_chip_class(filter_name)
    classes = ['filter-chip']
    classes << 'active' if Array(params[:filter]).map(&:to_s).include?(filter_name)
    classes.join(' ')
  end

  def event_filter_label(filter_name)
    EVENT_FILTER_LABELS.fetch(filter_name, filter_name.humanize)
  end

  def event_row_printer(event)
    case event.record
    when JobEvent then event.record.job.printer
    when PrinterEvent then event.record.printer
    end
  end

  def event_row_label(event)
    case event.record
    when JobEvent
      event.record.event_type.humanize
    when PrinterEvent
      'Filament change'
    end
  end

  def event_row_detail(event)
    case event.record
    when JobEvent
      parts = []
      if event.record.from_status.present?
        parts << "#{event.record.from_status} → #{event.record.to_status}"
      elsif event.record.to_status.present?
        parts << event.record.to_status
      end
      parts << event.record.message if event.record.message.present?
      parts.join(' · ')
    when PrinterEvent
      event.record.message
    end
  end

  def event_row_job(event)
    event.record.job if event.record.is_a?(JobEvent)
  end

  def event_status_dot_class(event)
    return 'status-muted' unless event.record.is_a?(JobEvent)

    case event.record.event_type
    when 'started' then 'status-success'
    when 'attention', 'error', 'paused' then 'status-warning'
    else 'status-muted'
    end
  end
end
