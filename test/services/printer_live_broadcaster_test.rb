require 'test_helper'

class PrinterLiveBroadcasterTest < ActiveSupport::TestCase
  test 'broadcasts live panel replacement' do
    printer = printers(:prusa_xl)
    called = false
    target = ActionView::RecordIdentifier.dom_id(printer, :live)

    replace = lambda do |streamable, **options|
      called = true

      assert_equal printer, streamable
      assert_equal target, options[:target]
      assert_equal 'printers/live_panel', options[:partial]
    end

    Turbo::StreamsChannel.stub(:broadcast_replace_to, replace) do
      PrinterLiveBroadcaster.broadcast(printer)
    end

    assert called
  end
end
