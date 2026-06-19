require 'test_helper'

class JobsHelperTest < ActionView::TestCase
  include JobsHelper

  setup do
    @job = jobs(:active_xl)
    @logged_in = false
    @can_clear_prints = false
  end

  def logged_in?
    @logged_in
  end

  def can_clear_prints?
    @can_clear_prints
  end

  test 'job_progress_bar_percent uses elapsed time when estimated finish is present' do
    freeze_time do
      @job.update!(
        started_at: 1.hour.ago,
        estimated_finish_at: 1.hour.from_now,
        progress_percent: 10.0
      )

      assert job_progress_timeline?(@job)
      assert_in_delta 50.0, job_progress_bar_percent(@job), 0.1
    end
  end

  test 'job_progress_bar_percent falls back to progress percent without an estimate' do
    @job.update!(progress_percent: 42.0, estimated_finish_at: nil)

    assert_not job_progress_timeline?(@job)
    assert_in_delta 42.0, job_progress_bar_percent(@job), 0.1
  end

  test 'job_timeline_end_label shows estimated finish for active jobs with eta' do
    freeze_time do
      estimated_finish_at = 45.minutes.from_now
      @job.update!(started_at: 15.minutes.ago, estimated_finish_at: estimated_finish_at, ended_at: nil)
      timeline = JobTimeline.new(@job)

      assert_match(/Est\. finish/, job_timeline_end_label(timeline))
      assert_match(/#{Regexp.escape(l(estimated_finish_at, format: :short))}/, job_timeline_end_label(timeline))
    end
  end

  test 'job_telemetry_section_label reflects job state' do
    assert_equal 'Current telemetry', job_telemetry_section_label(@job)

    @job.update!(status: 'finished', ended_at: Time.current)

    assert_equal 'Last telemetry', job_telemetry_section_label(@job)
  end

  test 'job action helpers reflect claim and clear eligibility' do
    @job.update!(owner: nil, cleared_at: nil, status: 'printing')

    assert_not job_show_claim_button?(@job)

    @logged_in = true

    assert job_show_claim_button?(@job)

    @can_clear_prints = true

    assert job_show_clear_button?(@job)

    @job.update!(owner: users(:viewer))

    assert_not job_show_claim_button?(@job)
  end

  test 'dashboard_action_job prefers current job over last job' do
    printer = printers(:prusa_xl)
    current_job = jobs(:active_xl)
    last_job = jobs(:finished)
    card = DashboardPresenter::Card.new(
      printer: printer,
      current_job: current_job,
      last_job: last_job,
      heads: [],
      snapshot: nil,
      latest_reading: nil
    )

    assert_equal current_job, dashboard_action_job(card)

    idle_card = DashboardPresenter::Card.new(
      printer: printer,
      current_job: nil,
      last_job: last_job,
      heads: [],
      snapshot: nil,
      latest_reading: nil
    )

    assert_equal last_job, dashboard_action_job(idle_card)
  end

  test 'job_progress_visible? requires timeline data or progress percent' do
    @job.update!(progress_percent: nil, estimated_finish_at: nil, started_at: nil)

    assert_not job_progress_visible?(@job)

    @job.update!(progress_percent: 12.0)

    assert job_progress_visible?(@job)
  end
end
