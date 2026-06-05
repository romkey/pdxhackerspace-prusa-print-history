class JobTimeline
  include JobTimelineCatalog
  include JobTimelineFormatting

  Segment = Data.define(:left_percent, :width_percent, :status, :css_class, :title)
  Marker = Data.define(:position_percent, :event_type, :short_label, :occurred_at, :title, :css_class)
  LegendEntry = Data.define(:letter, :label)
  StatusKey = Data.define(:css_class, :label)

  def initialize(job, events: nil, now: Time.current)
    @job = job
    @events = Array(events || job.events.ordered).sort_by(&:occurred_at)
    @now = now
  end

  def renderable?
    window_start.present? && window_end.present? && window_end >= window_start
  end

  def segments
    return [] unless renderable?

    build_segments
  end

  def markers
    return [] unless renderable?

    window_events.filter_map do |event|
      position = percent_for(event.occurred_at)
      next if position.nil?

      Marker.new(
        position_percent: position,
        event_type: event.event_type,
        short_label: MARKER_SHORT_LABELS.fetch(event.event_type, event.event_type.first.upcase),
        occurred_at: event.occurred_at,
        title: marker_title(event),
        css_class: MARKER_CLASSES.fetch(event.event_type, 'job-timeline__mark--muted')
      )
    end
  end

  def legend
    markers.map(&:event_type).uniq.map do |event_type|
      LegendEntry.new(
        letter: MARKER_SHORT_LABELS.fetch(event_type, event_type.first.upcase),
        label: MARKER_LABELS.fetch(event_type, event_type.humanize)
      )
    end.uniq.sort_by(&:letter)
  end

  def status_key
    segments.map(&:status).uniq.map do |status|
      StatusKey.new(
        css_class: STATUS_CLASSES.fetch(status, 'job-timeline__segment--pending'),
        label: STATUS_LABELS.fetch(status, status.humanize)
      )
    end.uniq
  end

  def start_at
    window_start
  end

  def end_at
    window_end
  end

  def active?
    @job.ended_at.blank?
  end

  private

  def build_segments
    points = status_points
    finish = window_end

    if points.size == 1
      start_time, = points.first
      segment = segment_between(start_time, finish, @job.status)
      return segment ? [segment] : []
    end

    segments = points.each_cons(2).filter_map do |(start_time, status), (end_time, _)|
      segment_between(start_time, end_time, status)
    end

    last_time, = points.last
    tail = segment_between(last_time, finish, @job.status)
    segments << tail if tail
    segments
  end

  def segment_between(start_time, end_time, status)
    left = percent_for(start_time)
    width = percent_for(end_time) - left
    return if width <= 0.1

    Segment.new(
      left_percent: left,
      width_percent: width,
      status: status,
      css_class: STATUS_CLASSES.fetch(status, 'job-timeline__segment--pending'),
      title: segment_title(status, end_time - start_time)
    )
  end

  def status_points
    start = window_start
    return [[start, @job.status]] if window_events.empty?

    points = [[start, initial_status(window_events.first)]]
    window_events.each do |event|
      append_point(points, clamp_time(event.occurred_at), status_for_event(event))
    end
    points
  end

  def window_events
    @window_events ||= @events.select { |event| event.occurred_at.between?(window_start, window_end) }
  end

  def append_point(points, time, status)
    if points.last&.first == time
      points[-1] = [time, status]
    else
      points << [time, status]
    end
  end

  def percent_for(time)
    return 0 if time <= window_start
    return 100 if time >= window_end

    ((time - window_start) / duration_seconds * 100).round(2)
  end

  def clamp_time(time)
    time.clamp(window_start, window_end)
  end

  def window_start
    @window_start ||= @job.started_at || @events.first&.occurred_at || @job.created_at
  end

  def window_end
    @window_end ||= @job.ended_at || @now
  end

  def duration_seconds
    [(window_end - window_start).to_f, 1.0].max
  end
end
