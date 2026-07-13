module PrusaConnect
  class PhotoUpload
    MIN_UPLOAD_INTERVAL = 10.seconds

    def self.enqueue!(printer, attachable)
      return unless printer.prusa_connect?

      PrusaConnectPhotoUploadJob.perform_later(printer.id, attachable.class.name, attachable.id)
    end

    def self.upload!(printer, body:, content_type: 'image/jpeg', client: Client.new(printer))
      return unless printer.prusa_connect?
      return if rate_limited?(printer)

      client.upload_snapshot(body, content_type: content_type)
      printer.update!(prusa_connect_last_uploaded_at: Time.current)
    rescue RateLimited
      Rails.logger.info(
        "Prusa Connect upload skipped for printer ##{printer.id} (#{printer.name}): rate limited"
      )
    end

    def self.rate_limited?(printer)
      last = printer.prusa_connect_last_uploaded_at
      last.present? && last > MIN_UPLOAD_INTERVAL.ago
    end
  end
end
