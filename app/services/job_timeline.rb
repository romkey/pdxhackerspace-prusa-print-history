class JobTimeline
  Segment = Data.define(:left_percent, :width_percent, :status, :css_class)
  Marker = Data.define(:position_percent, :event_type, :label, :occurred_at, :title, :css_class)

  STATUS_CLASSES = {
    'printing' => 'job-timeline-segment--printing',
    'paused' => 'job-timeline-segment--paused',
    'attention' => 'job-timeline-segment--attention',
    'error' => 'job-timeline-segment--error',
    'finished' => 'job-timeline-segment--finished',
    'cancelled' => 'job-timeline-segment--cancelled',
    'pending' => 'job-timeline-segment--pending'
  }.freeze

  MARKER_CLASSES = {
    'started' => 'job-timeline-marker--success',
    'resumed' => 'job-timeline-marker--success',
    'attention' => 'job-timeline-marker--danger',
    'error' => 'job-timeline-marker--danger',
    'paused' => 'job-timeline-marker--warning',
    'finished' => 'job-timeline-marker--muted',
    'cancelled' => 'job-timeline-marker--muted',
    'status_changed' => 'job-timeline-marker--muted'
  }.freeze

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

    @events.filter_map do |event|
      position = percent_for(event.occurred_at)
      next if position.nil?

      Marker.new(
        position_percent: position,
        event_type: event.event_type,
        label: event.event_type.humanize,
        occurred_at: event.occurred_at,
        title: marker_title(event),
        css_class: MARKER_CLASSES.fetch(event.event_type, 'job-timeline-marker--muted')
      )
    end
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
    return [single_segment(@job.status)] if points.size == 1

    points.each_cons(2).filter_map do |(start_time, status), (end_time, _)|
      left = percent_for(start_time)
      width = percent_for(end_time) - left
      next if width <= 0

      Segment.new(
        left_percent: left,
        width_percent: width,
        status: status,
        css_class: STATUS_CLASSES.fetch(status, 'job-timeline-segment--pending')
      )
    end
  end

  def status_points
    start = window_start
    finish = window_end
    return [[start, @job.status]] if @events.empty?

    points = [[start, initial_status(@events.first)]]
    @events.each do |event|
      status = event.to_status.presence || @job.status
      points << [clamp_time(event.occurred_at), status]
    end
    points << [finish, points.last[1]]
    points
  end

  def initial_status(first_event)
    first_event.from_status.presence || 'pending'
  end

  def single_segment(status)
    Segment.new(
      left_percent: 0,
      width_percent: 100,
      status: status,
      css_class: STATUS_CLASSES.fetch(status, 'job-timeline-segment--pending')
    )
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
