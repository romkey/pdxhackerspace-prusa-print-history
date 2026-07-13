class PrusaConnectPhotoUploadJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(printer_id, attachable_type, attachable_id)
    printer = Printer.find(printer_id)
    attachable = attachable_type.constantize.find(attachable_id)
    attachment = attachment_for(attachable)
    return unless attachment&.attached?

    PrusaConnect::PhotoUpload.upload!(
      printer,
      body: attachment.download,
      content_type: attachment.content_type
    )
  end

  private

  def attachment_for(attachable)
    case attachable
    when PhotoCapture then attachable.image
    when JobEvent then attachable.photo
    end
  end
end
