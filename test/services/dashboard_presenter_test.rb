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
      recent_events: []
    )

    card = presenter.cards.first

    assert_equal printer, card.printer
    assert_equal job, card.current_job
    assert card.printing?
    assert_equal 'PLA', card.material_label
    assert_equal '0.4mm', card.nozzle_label
    assert_in_delta 55.0, card.bed_temp_c
    assert_in_delta 215.0, card.nozzle_temp_c
    assert_in_delta 30.0, card.enclosure_temp_c
    assert_in_delta 21.0, card.ambient_temp_c
  end

  test 'availability reflects PrusaLink connection status' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true)

    card = DashboardPresenter.new(
      printers: [printer],
      active_jobs_by_printer: {},
      recent_events: []
    ).cards.first

    assert_equal 'available', card.availability_label
    assert_not card.availability_muted?

    printer.update!(prusalink_reachable: false)

    card = DashboardPresenter.new(
      printers: [printer.reload],
      active_jobs_by_printer: {},
      recent_events: []
    ).cards.first

    assert_equal 'unavailable', card.availability_label
    assert card.availability_muted?
  end
end
