require 'test_helper'

class ServiceEntryTest < ActiveSupport::TestCase
  setup do
    @printer = printers(:prusa_mini)
    @user = users(:viewer)
  end

  test 'requires a summary, kind, and time' do
    entry = ServiceEntry.new(printer: @printer, kind: 'nope')

    assert_not entry.valid?
    assert_includes entry.errors[:summary], "can't be blank"
    assert_includes entry.errors[:kind], 'is not included in the list'
    assert_includes entry.errors[:occurred_at], "can't be blank"
  end

  test 'open scope is unresolved problem reports' do
    open_problem = entry(kind: 'problem', summary: 'Belt slip')
    entry(kind: 'problem', summary: 'Fixed noise', resolved_at: Time.current, resolved_by: @user)
    entry(kind: 'repair', summary: 'New belt')

    assert_equal [open_problem], @printer.service_entries.open.to_a
  end

  test 'only problem reports can be resolved' do
    repair = entry(kind: 'repair', summary: 'New belt')
    repair.resolved_at = Time.current

    assert_not repair.valid?
    assert_includes repair.errors[:base], 'Only problem reports can be resolved'
  end

  private

  def entry(**attrs)
    @printer.service_entries.create!(
      { kind: 'problem', summary: 'Noise', occurred_at: Time.current, user: @user }.merge(attrs)
    )
  end
end
