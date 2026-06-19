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

  test 'filters cards with stacked status and material filters' do
    xl = printers(:prusa_xl)
    mk4 = printers(:prusa_mk4)
    mini = printers(:prusa_mini)
    xl.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    mk4.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'attention')
    mini.update!(prusalink_key: 'secret', prusalink_reachable: false, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)
    jobs(:orphaned_active).update!(status: 'attention')

    presenter = build_presenter(filters: %w[idle PLA])

    assert_equal([xl.name], presenter.filtered_cards.map { |card| card.printer.name })
  end

  test 'idle filter matches reachable idle printers only' do
    xl = printers(:prusa_xl)
    mini = printers(:prusa_mini)
    xl.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    mini.update!(prusalink_key: 'secret', prusalink_reachable: false, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)

    presenter = build_presenter(filters: ['idle'])

    assert_equal([xl.name], presenter.filtered_cards.map { |card| card.printer.name })
  end

  test 'printing filter matches reachable printing printers only' do
    xl = printers(:prusa_xl)
    mk4 = printers(:prusa_mk4)
    xl.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    mk4.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'attention')
    jobs(:active_xl).update!(status: 'printing')
    jobs(:orphaned_active).update!(status: 'attention')

    presenter = build_presenter(filters: ['printing'])

    assert_equal([xl.name], presenter.filtered_cards.map { |card| card.printer.name })
  end

  test 'normalize_filters keeps only one exclusive status filter' do
    presenter = build_presenter(filters: %w[idle printing attention])

    assert_equal ['attention'], presenter.active_filters & DashboardPresenter::EXCLUSIVE_STATUS_FILTERS

    presenter = build_presenter(filters: %w[idle offline])

    assert_equal ['offline'], presenter.active_filters & DashboardPresenter::EXCLUSIVE_STATUS_FILTERS
  end

  test 'offline filter matches unreachable printers' do
    xl = printers(:prusa_xl)
    mk4 = printers(:prusa_mk4)
    mini = printers(:prusa_mini)
    xl.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    mk4.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'attention')
    mini.update!(prusalink_key: 'secret', prusalink_reachable: false, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)
    jobs(:orphaned_active).update!(status: 'attention')

    presenter = build_presenter(filters: ['offline'])

    assert_equal([mini.name], presenter.filtered_cards.map { |card| card.printer.name })
  end

  test 'my prints filter matches current or last job owner' do
    xl = printers(:prusa_xl)
    mk4 = printers(:prusa_mk4)
    xl.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    mk4.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'attention')
    jobs(:active_xl).update!(owner: users(:viewer), status: 'printing')
    jobs(:orphaned_active).update!(owner: users(:other_viewer), status: 'attention')

    presenter = build_presenter(filters: ['my_prints'], current_user: users(:viewer))

    assert_equal([xl.name], presenter.filtered_cards.map { |card| card.printer.name })
  end

  test 'attention filter matches reachable printers in attention states' do
    xl = printers(:prusa_xl)
    mk4 = printers(:prusa_mk4)
    xl.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    mk4.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'attention')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)
    jobs(:orphaned_active).update!(status: 'attention')

    presenter = build_presenter(filters: ['attention'])

    assert_equal([mk4.name], presenter.filtered_cards.map { |card| card.printer.name })
  end

  test 'material_filters lists loaded filaments in use' do
    presenter = build_presenter

    assert_equal %w[ASA PETG PLA], presenter.material_filters
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

  def build_presenter(filters: [], current_user: nil)
    printers = Printer.ordered.includes(:printer_heads)
    active_jobs = Job.active.where(printer_id: printers.map(&:id)).index_by(&:printer_id)
    last_jobs = Job.where(printer_id: printers.map(&:id)).recent.to_a.group_by(&:printer_id).transform_values(&:first)
    active_jobs.each_key { |printer_id| last_jobs.delete(printer_id) }

    DashboardPresenter.new(
      printers: printers,
      active_jobs_by_printer: active_jobs,
      last_jobs_by_printer: last_jobs,
      recent_events: [],
      filters: filters,
      current_user: current_user
    )
  end
end
