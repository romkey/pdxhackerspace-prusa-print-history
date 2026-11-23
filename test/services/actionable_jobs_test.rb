require 'test_helper'

class ActionableJobsTest < ActiveSupport::TestCase
  test 'picks the active print, or else the latest print if it still needs clearing' do
    jobs_by_printer = ActionableJobs.by_printer(Printer.all)

    assert_equal jobs(:active_xl), jobs_by_printer[printers(:prusa_xl).id]
    assert_equal jobs(:orphaned_active), jobs_by_printer[printers(:prusa_mk4).id]
    assert_equal jobs(:finished_old), jobs_by_printer[printers(:prusa_mini).id]
    assert_nil jobs_by_printer[printers(:bambu_p2s).id]
  end

  test 'a cleared latest print leaves nothing to act on' do
    jobs(:finished_old).update!(cleared_at: 1.hour.ago, clear_outcome: 'success')

    assert_nil ActionableJobs.by_printer([printers(:prusa_mini)])[printers(:prusa_mini).id]
  end

  test 'loads one job per printer, not the whole history' do
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "jobs"') }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      ActionableJobs.by_printer(Printer.all)
    end

    assert(queries.all? { |sql| sql.include?('DISTINCT ON') })
  end
end
