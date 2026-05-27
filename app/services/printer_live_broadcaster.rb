class PrinterLiveBroadcaster
  def self.broadcast(printer)
    AppUrl.with_url_options do
      broadcast_with_urls(printer)
    end
  end

  def self.broadcast_with_urls(printer)
    printer = printer.reload
    presenter = PrinterShowPresenter.new(printer)

    Turbo::StreamsChannel.broadcast_replace_to(
      printer,
      target: ActionView::RecordIdentifier.dom_id(printer, :live),
      partial: 'printers/live_panel',
      locals: presenter.locals
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      printer,
      target: ActionView::RecordIdentifier.dom_id(printer, :prusalink_status),
      partial: 'printers/prusalink_status_dot',
      locals: { printer: printer }
    )
  end

  private_class_method :broadcast_with_urls
end
