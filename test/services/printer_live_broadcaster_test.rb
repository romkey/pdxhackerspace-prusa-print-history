require 'test_helper'

class PrinterLiveBroadcasterTest < ActiveSupport::TestCase
  test 'broadcasts live panel and PrusaLink status updates' do
    printer = printers(:prusa_xl)
    targets = []
    live_target = ActionView::RecordIdentifier.dom_id(printer, :live)
    status_target = ActionView::RecordIdentifier.dom_id(printer, :prusalink_status)

    replace = lambda do |streamable, **options|
      targets << options[:target]

      assert_equal printer, streamable
      assert_includes [live_target, status_target], options[:target]
    end

    Turbo::StreamsChannel.stub(:broadcast_replace_to, replace) do
      PrinterLiveBroadcaster.broadcast(printer)
    end

    assert_equal [live_target, status_target], targets
  end
end
