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
    assert_equal 'job-timeline-segment--printing', segments.first.css_class
    assert_operator segments.first.width_percent, :>, 0
    assert_equal 'job-timeline-segment--attention', segments.last.css_class
  end

  test 'places markers at event times with titles' do
    timeline = JobTimeline.new(@job, now: @now)
    markers = timeline.markers

    assert_equal 2, markers.size
    assert_equal 'started', markers.first.event_type
    assert_includes markers.last.title, 'Filament runout'
    assert_operator markers.last.position_percent, :>, markers.first.position_percent
  end

  test 'uses ended_at as timeline end for finished jobs' do
    ended_at = @now - 5.minutes
    @job.update!(status: 'finished', ended_at: ended_at)
    timeline = JobTimeline.new(@job, now: @now)

    assert_not timeline.active?
    assert_equal @job.ended_at, timeline.end_at
  end

  test 'is not renderable without a start time' do
    job = Job.new(filename: 'orphan.gcode', status: 'pending', printer: printers(:prusa_xl))
    timeline = JobTimeline.new(job, events: [], now: @now)

    assert_not timeline.renderable?
  end
end
