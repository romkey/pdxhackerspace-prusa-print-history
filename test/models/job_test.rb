require 'test_helper'

class JobTest < ActiveSupport::TestCase
  setup do
    @active = jobs(:active_xl)
    @done   = jobs(:finished)
  end

  test 'requires filename and status' do
    job = Job.new(printer: printers(:prusa_mini), filename: nil, status: nil)

    assert_not job.valid?
    assert_includes job.errors[:filename], "can't be blank"
    assert_includes job.errors[:status], "can't be blank"
  end

  test 'status must be in the enum list' do
    @active.status = 'made_up_state'

    assert_not @active.valid?
    assert_includes @active.errors[:status], 'is not included in the list'
  end

  test 'active scope contains running jobs only' do
    assert_includes Job.active, @active
    assert_not_includes Job.active, @done
  end

  test 'terminal scope contains finished/cancelled jobs' do
    assert_includes Job.terminal, @done
    assert_not_includes Job.terminal, @active
  end

  test 'owned_by filters by owner' do
    assert_equal [@active.id, @done.id].sort, Job.owned_by(users(:viewer)).pluck(:id).sort
    assert_empty Job.owned_by(users(:admin))
  end

  test 'duration_seconds prefers stored value, otherwise computes from timestamps' do
    assert_equal 7200, @done.duration_seconds

    @active.update!(started_at: 5.minutes.ago, total_duration_seconds: nil)

    assert_in_delta 300, @active.duration_seconds, 5
  end

  test 'prusalink_job_id is unique per printer when present' do
    duplicate = Job.new(printer: @active.printer,
                        filename: 'x.gcode',
                        status: 'pending',
                        prusalink_job_id: @active.prusalink_job_id)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:prusalink_job_id], 'has already been taken'

    nil_one = Job.new(printer: @active.printer, filename: 'x.gcode', status: 'pending', prusalink_job_id: nil)
    nil_two = Job.new(printer: @active.printer, filename: 'y.gcode', status: 'pending', prusalink_job_id: nil)

    assert nil_one.save
    assert nil_two.save
  end

  test 'label_printable? is true for active and finished jobs' do
    assert jobs(:active_xl).label_printable?
    assert jobs(:finished).label_printable?
    assert_not Job.new(status: 'pending').label_printable?
  end
end
