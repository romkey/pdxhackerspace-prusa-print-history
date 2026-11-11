# Shared failure type for printer transports. PrusaLink and Bambu LAN both
# subclass it so the poller and controllers can rescue one error.
module PrinterConnection
  class Error < StandardError; end
end
