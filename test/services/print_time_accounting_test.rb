require 'test_helper'

class PrintTimeAccountingTest < ActiveSupport::TestCase
  test 'sync_user_total! sums terminal owned job durations' do
    viewer = users(:viewer)
    viewer.update!(total_print_seconds: 0)

    PrintTimeAccounting.sync_user_total!(viewer)

    assert_equal 7200, viewer.reload.total_print_seconds
  end

  test 'sync_users_for_job! updates previous and current owners' do
    job = jobs(:finished)
    previous_owner = job.owner
    new_owner = users(:other_viewer)

    job.update!(owner: new_owner)

    assert_equal 0, previous_owner.reload.total_print_seconds
    assert_equal 10_800, new_owner.reload.total_print_seconds
  end

  test 'job updates recalculate owner total when a finished job duration changes' do
    job = jobs(:finished)
    viewer = job.owner
    viewer.update!(total_print_seconds: 7200)

    job.update!(total_duration_seconds: 9000)

    assert_equal 9000, viewer.reload.total_print_seconds
  end
end
