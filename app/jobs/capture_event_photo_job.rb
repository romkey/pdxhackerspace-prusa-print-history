class CaptureEventPhotoJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(event_id)
    event = JobEvent.find(event_id)
    return if event.photo.attached?

    snapshot = PrinterCamera.snapshot(event.job.printer)
    return if snapshot.nil?

    event.photo.attach(
      io: snapshot[:io],
      filename: snapshot[:filename],
      content_type: snapshot[:content_type]
    )

    PrusaConnect::PhotoUpload.enqueue!(event.job.printer, event)
  end
end
