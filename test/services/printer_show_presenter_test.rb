require 'test_helper'

class PrinterShowPresenterTest < ActiveSupport::TestCase
  setup do
    @printer = printers(:prusa_xl)
    @presenter = PrinterShowPresenter.new(@printer)
  end

  test 'uses current job when printer is active' do
    assert_equal jobs(:active_xl), @presenter.current_job
    assert_equal jobs(:active_xl), @presenter.display_job
  end

  test 'falls back to most recent job when idle' do
    active = jobs(:active_xl)
    active.update!(status: 'finished', ended_at: Time.current)
    @printer.update!(operational_state: 'idle')
    presenter = PrinterShowPresenter.new(@printer.reload)

    assert_nil presenter.current_job
    assert_equal active, presenter.display_job
    assert presenter.chart_series.any?
  end

  test 'exposes tool and telemetry data for display job' do
    assert @presenter.tools.any?
    assert @presenter.latest_reading.present?
    assert @presenter.live_tool_temps.any?
  end

  test 'camera_refresh_token uses latest photo timestamp' do
    capture = @printer.photo_captures.create!(captured_at: 5.minutes.ago)
    capture.image.attach(
      io: StringIO.new('bytes'),
      filename: 'photo.jpg',
      content_type: 'image/jpeg'
    )

    assert_equal capture.captured_at.to_i, @presenter.camera_refresh_token
  end

  test 'reported_tools prefers printer heads over job history' do
    assert @presenter.reported_tools.any?
    assert_equal printer_heads(:xl_head_a).material, @presenter.reported_tools.first.material
  end
end
