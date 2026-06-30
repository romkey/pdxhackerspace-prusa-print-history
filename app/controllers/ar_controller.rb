class ArController < ApplicationController
  before_action :require_login_or_internal

  layout false

  # Number of printable AR markers shipped in public/ar/markers (marker-0..6).
  MARKER_COUNT = 7

  def show
    @printers = Printer.ordered.includes(:printer_heads).limit(MARKER_COUNT)
  end
end
