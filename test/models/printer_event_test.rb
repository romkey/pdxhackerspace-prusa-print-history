require 'test_helper'

class PrinterEventTest < ActiveSupport::TestCase
  test 'validates event type' do
    event = PrinterEvent.new(
      printer: printers(:prusa_xl),
      event_type: 'filament_change',
      tool_index: 0,
      occurred_at: Time.current
    )

    assert event.valid?
  end

  test 'rejects unknown event type' do
    event = PrinterEvent.new(
      printer: printers(:prusa_xl),
      event_type: 'started',
      occurred_at: Time.current
    )

    assert_not event.valid?
  end
end
