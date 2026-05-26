require 'test_helper'

class JobEventTest < ActiveSupport::TestCase
  test 'event_type must be one of the known values' do
    event = JobEvent.new(job: jobs(:active_xl), event_type: 'invalid', occurred_at: Time.current)

    assert_not event.valid?
    assert_includes event.errors[:event_type], 'is not included in the list'
  end

  test 'photo attachment is optional' do
    event = JobEvent.new(job: jobs(:active_xl), event_type: 'started', occurred_at: Time.current)

    assert_predicate event, :valid?
    assert_not event.photo.attached?
  end

  test 'recent scope sorts newest first' do
    ids = JobEvent.recent.pluck(:id)
    occurred = JobEvent.recent.pluck(:occurred_at)

    assert_equal occurred.sort.reverse, occurred
    assert_predicate ids, :any?
  end
end
