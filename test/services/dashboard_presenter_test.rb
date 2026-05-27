require 'test_helper'

class DashboardPresenterTest < ActiveSupport::TestCase
  test 'builds cards with active job progress and printer heads' do
    printer = printers(:prusa_xl)
    job = jobs(:active_xl)
    job.update!(progress_percent: 42.0, estimated_finish_at: 30.minutes.from_now, time_printing_seconds: 600)

    presenter = DashboardPresenter.new(
      printers: [printer],
      active_jobs_by_printer: { printer.id => job },
      recent_events: []
    )

    card = presenter.cards.first

    assert_equal printer, card.printer
    assert_equal job, card.current_job
    assert card.printing?
    assert_includes card.head_labels, 'PLA'
  end
end
