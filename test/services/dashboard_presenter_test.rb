require 'test_helper'

class DashboardPresenterTest < ActiveSupport::TestCase
  test 'builds cards with active job, heads, and temperatures' do
    printer = printers(:prusa_xl)
    job = jobs(:active_xl)
    job.update!(progress_percent: 42.0, estimated_finish_at: 30.minutes.from_now, time_printing_seconds: 600)
    job.telemetry_readings.create!(
      recorded_at: Time.current,
      bed_temp: 55.0,
      tool_temps: { '0' => 215.0 },
      enclosure_temp: 30.0,
      ambient_temp: 21.0
    )

    presenter = DashboardPresenter.new(
      printers: [printer],
      active_jobs_by_printer: { printer.id => job },
      last_jobs_by_printer: {},
      recent_events: []
    )

    card = presenter.cards.first

    assert_equal printer, card.printer
    assert_equal job, card.current_job
    assert_nil card.last_job
    assert card.printing?
    assert_equal 'PLA', card.material_label
    assert_equal '0.4mm', card.nozzle_label
    assert_in_delta 55.0, card.bed_temp_c
    assert_in_delta 215.0, card.nozzle_temp_c
    assert_in_delta 30.0, card.enclosure_temp_c
    assert_in_delta 21.0, card.ambient_temp_c
  end

  test 'idle cards use the last job for preview and metadata' do
    printer = printers(:prusa_xl)
    last_job = jobs(:active_xl)
    last_job.update!(status: 'finished', ended_at: 5.minutes.ago)

    presenter = DashboardPresenter.new(
      printers: [printer],
      active_jobs_by_printer: {},
      last_jobs_by_printer: { printer.id => last_job },
      recent_events: []
    )

    card = presenter.cards.first

    assert card.idle?
    assert_equal last_job, card.last_job
    assert_equal last_job, card.preview_job
    assert_equal 'dragon.gcode', card.last_job.filename
    assert_equal 'finished', card.last_job.status
  end

  test 'image outline status reflects printer state and availability' do
    printer = printers(:prusa_mini)
    printer.update!(prusalink_key: 'secret', operational_state: 'idle', prusalink_reachable: true)

    card = build_card(printer)

    assert_equal 'ready', card.image_outline_status

    printer.update!(operational_state: 'printing')
    job = Job.create!(
      printer: printer,
      filename: 'cube.gcode',
      status: 'printing',
      started_at: 5.minutes.ago
    )
    card = build_card(printer, active_jobs: { printer.id => job })

    assert_equal 'printing', card.image_outline_status

    printer.update!(operational_state: 'paused')
    job.update!(status: 'paused')
    card = build_card(printer, active_jobs: { printer.id => job })

    assert_equal 'attention', card.image_outline_status

    job.update!(status: 'finished', ended_at: Time.current)
    printer.update!(operational_state: 'unknown', prusalink_reachable: true)
    card = build_card(printer)

    assert_equal 'ready', card.image_outline_status

    printer.update!(prusalink_reachable: false, operational_state: 'idle')
    card = build_card(printer)

    assert_equal 'ready', card.image_outline_status

    printer.update!(operational_state: 'attention')
    card = build_card(printer)

    assert_equal 'attention', card.image_outline_status
  end

  private

  def build_card(printer, active_jobs: {}, last_jobs: {})
    DashboardPresenter.new(
      printers: [printer],
      active_jobs_by_printer: active_jobs,
      last_jobs_by_printer: last_jobs,
      recent_events: []
    ).cards.first
  end
end
