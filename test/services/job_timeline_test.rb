require 'test_helper'

class JobTimelineTest < ActiveSupport::TestCase
  setup do
    @job = jobs(:active_xl)
    @now = Time.zone.parse('2026-05-30 14:00:00')
    @started_at = @now - 30.minutes
    @attention_at = @now - 10.minutes

    @job.update!(started_at: @started_at, status: 'attention', ended_at: nil)
    @job.events.destroy_all
    @job.events.create!(event_type: 'started', to_status: 'printing', occurred_at: @started_at)
    @job.events.create!(
      event_type: 'attention',
      from_status: 'printing',
      to_status: 'attention',
      message: 'Filament runout',
      occurred_at: @attention_at
    )
  end

  test 'builds colored segments across the print window' do
    timeline = JobTimeline.new(@job, now: @now)
    segments = timeline.segments

    assert_equal 2, segments.size
    assert_equal 'job-timeline__segment--printing', segments.first.css_class
    assert_includes segments.first.title, '20m'
    assert_operator segments.first.width_percent, :>, 0
    assert_equal 'job-timeline__segment--attention', segments.last.css_class
    assert_includes segments.last.title, '10m'
    assert_in_delta 100, segments.sum(&:width_percent), 0.5
  end

  test 'places labeled markers at every event time' do
    timeline = JobTimeline.new(@job, now: @now)
    markers = timeline.markers

    assert_equal 2, markers.size
    assert_equal %w[S A], markers.map(&:short_label)
    assert_equal 'started', markers.first.event_type
    assert_includes markers.last.title, 'Filament runout'
    assert_operator markers.last.position_percent, :>, markers.first.position_percent
  end

  test 'legend lists only used letters alphabetically' do
    timeline = JobTimeline.new(@job, now: @now)

    legend = timeline.legend

    assert_equal %w[A S], legend.map(&:letter)
    assert_equal %w[Attention Started], legend.map(&:label)
  end

  test 'legend deduplicates repeated event types' do
    @job.events.create!(event_type: 'attention', to_status: 'attention', occurred_at: @now - 2.minutes)

    legend = JobTimeline.new(@job, now: @now).legend

    assert_equal %w[A S], legend.map(&:letter)
  end

  test 'status key covers the colors actually drawn' do
    key = JobTimeline.new(@job, now: @now).status_key

    classes = key.map(&:css_class)

    assert_includes classes, 'job-timeline__segment--printing'
    assert_includes classes, 'job-timeline__segment--attention'
    assert_equal classes, classes.uniq
  end

  test 'tail segment reflects current job status after last event' do
    resumed_at = @now - 5.minutes
    @job.update!(status: 'printing')
    @job.events.create!(
      event_type: 'resumed',
      from_status: 'attention',
      to_status: 'printing',
      occurred_at: resumed_at
    )

    segments = JobTimeline.new(@job, now: @now).segments

    assert_equal 'job-timeline__segment--printing', segments.last.css_class
    assert_includes segments.last.title, '5m'
  end

  test 'uses ended_at as timeline end for finished jobs' do
    ended_at = @now - 5.minutes
    @job.update!(status: 'finished', ended_at: ended_at)
    timeline = JobTimeline.new(@job, now: @now)

    assert_not timeline.active?
    assert_equal @job.ended_at, timeline.end_at
  end

  test 'extends timeline to estimated finish and leaves future portion empty' do
    estimated_finish_at = @now + 30.minutes
    @job.update!(estimated_finish_at: estimated_finish_at)
    timeline = JobTimeline.new(@job, now: @now)

    assert timeline.estimated_finish?
    assert_equal estimated_finish_at, timeline.end_at
    assert_operator timeline.segments.sum(&:width_percent), :<, 100
    assert_in_delta 50.0, timeline.segments.sum(&:width_percent), 0.5
  end

  test 'is not renderable without a start time' do
    job = Job.new(filename: 'orphan.gcode', status: 'pending', printer: printers(:prusa_xl))
    timeline = JobTimeline.new(job, events: [], now: @now)

    assert_not timeline.renderable?
  end

  test 'every emitted css class has a matching rule in the stylesheet' do
    stylesheet = Rails.root.join('app/assets/stylesheets/refresh.scss').read
    defined_selectors = stylesheet.scan(/\.([\w-]+)\s*[,{]/).flatten.to_set

    emitted = JobTimelineCatalog::STATUS_CLASSES.values + JobTimelineCatalog::MARKER_CLASSES.values
    missing = emitted.uniq.reject { |css_class| defined_selectors.include?(css_class) }

    assert_empty missing, "Timeline classes with no CSS rule: #{missing.join(', ')}"
  end
end
