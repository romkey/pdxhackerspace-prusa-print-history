class PrinterPhotoCapture
  def self.capture!(printer, job: nil, client: nil)
    new(printer, job: job, client: client).capture!
  end

  def initialize(printer, job: nil, client: nil)
    @printer = printer
    @job = job
    @client = client
  end

  def capture!
    return unless @printer.camera? || @printer.prusalink?

    snapshot = PrinterCamera.snapshot(@printer, client: @client)
    return if snapshot.nil?

    if @job&.active?
      save_progress_capture!(snapshot)
    else
      replace_idle_capture!(snapshot)
    end

    PrinterLiveBroadcaster.broadcast(@printer)
  end

  private

  def save_progress_capture!(snapshot)
    capture = @printer.photo_captures.create!(job: @job, captured_at: Time.current)
    attach_image!(capture, snapshot)
    capture
  end

  def replace_idle_capture!(snapshot)
    @printer.photo_captures.idle.find_each do |old|
      old.image.purge if old.image.attached?
      old.destroy!
    end

    capture = @printer.photo_captures.create!(captured_at: Time.current)
    attach_image!(capture, snapshot)
    capture
  end

  def attach_image!(capture, snapshot)
    body = snapshot[:io].respond_to?(:rewind) ? snapshot[:io].tap(&:rewind).read : snapshot[:io].to_s

    capture.image.attach(
      io: StringIO.new(body.dup.force_encoding(Encoding::BINARY)),
      filename: snapshot[:filename],
      content_type: snapshot[:content_type]
    )
  end
end
