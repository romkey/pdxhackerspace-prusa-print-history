class PrinterLiveBroadcaster
  def self.broadcast(printer)
    presenter = PrinterShowPresenter.new(printer.reload)

    Turbo::StreamsChannel.broadcast_replace_to(
      printer,
      target: ActionView::RecordIdentifier.dom_id(printer, :live),
      partial: 'printers/live_panel',
      locals: presenter.locals
    )
  end
end
