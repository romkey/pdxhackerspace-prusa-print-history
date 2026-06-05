module JobTimelineFormatting
  private

  def initial_status(first_event)
    first_event.from_status.presence || status_for_event(first_event)
  end

  def status_for_event(event)
    event.to_status.presence || inferred_status_for(event)
  end

  def inferred_status_for(event)
    case event.event_type
    when 'started', 'resumed' then 'printing'
    when 'attention' then 'attention'
    when 'error' then 'error'
    when 'paused' then 'paused'
    when 'finished' then 'finished'
    when 'cancelled' then 'cancelled'
    else @job.status
    end
  end

  def segment_title(status, seconds)
    "#{status.humanize} · #{duration_label(seconds)}"
  end

  def duration_label(seconds)
    total = seconds.to_i
    hours, remainder = total.divmod(3600)
    minutes, secs = remainder.divmod(60)

    if hours.positive?
      minutes.positive? ? "#{hours}h #{minutes}m" : "#{hours}h"
    elsif minutes.positive?
      "#{minutes}m"
    else
      "#{secs}s"
    end
  end

  def marker_title(event)
    parts = [event.event_type.humanize]
    if event.from_status.present? && event.to_status.present?
      parts << "#{event.from_status} → #{event.to_status}"
    elsif event.to_status.present?
      parts << event.to_status
    end
    parts << event.message if event.message.present?
    parts.join(' · ')
  end
end
