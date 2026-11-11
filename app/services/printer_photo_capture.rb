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
    return unless @printer.capture_photos?

    Rails.logger.info("Photo capture #{@printer.name}: start #{capture_source}")
    snapshot = PrinterCamera.snapshot(@printer, client: @client)
    if snapshot.nil?
      Rails.logger.info("Photo capture #{@printer.name}: no frame")
      return
    end

    if @job&.active?
      save_progress_capture!(snapshot)
    else
      replace_idle_capture!(snapshot)
    end

    PrinterLiveBroadcaster.broadcast(@printer)
    Rails.logger.info("Photo capture #{@printer.name}: stored #{snapshot_bytes(snapshot)} bytes")
  end

  private

  def capture_source
    return 'camera url' if @printer.camera?
    return bambu_source if @printer.bambu?

    'prusalink'
  end

  def bambu_source
    transport = BambuLan::Models.camera(@printer.model)
    "bambu #{@printer.model} #{transport} #{BambuLan::Host.for(@printer)}"
  end

  def snapshot_bytes(snapshot)
    io = snapshot[:io]
    io.rewind if io.respond_to?(:rewind)
    io.size
  end

  def save_progress_capture!(snapshot)
    capture = @printer.photo_captures.create!(job: @job, captured_at: Time.current)
    attach_image!(capture, snapshot)
    PrusaConnect::PhotoUpload.enqueue!(@printer, capture)
    capture
  end

  def replace_idle_capture!(snapshot)
    @printer.photo_captures.idle.find_each do |old|
      old.image.purge if old.image.attached?
      old.destroy!
    end

    capture = @printer.photo_captures.create!(captured_at: Time.current)
    attach_image!(capture, snapshot)
    PrusaConnect::PhotoUpload.enqueue!(@printer, capture)
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
