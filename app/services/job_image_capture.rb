class JobImageCapture
  def self.capture_preview!(job, job_payload, client:)
    new(job, job_payload, client: client).capture_preview!
  end

  def initialize(job, job_payload, client:)
    @job = job
    @job_payload = job_payload
    @client = client
  end

  def capture_preview!
    return if @job.preview_image.attached?

    path = thumbnail_path
    return if path.blank?

    attach_preview(@client.download(path), path)
  rescue PrusaLink::Error => e
    Rails.logger.warn("JobImageCapture preview failed for job ##{@job.id}: #{e.message}")
    nil
  end

  private

  def thumbnail_path
    refs = @job_payload&.dig('file', 'refs') || {}
    refs['thumbnail'].presence || refs['icon'].presence
  end

  def attach_preview(body, path)
    return if body.blank?

    @job.preview_image.attach(
      io: StringIO.new(body.dup.force_encoding(Encoding::BINARY)),
      filename: preview_filename(path),
      content_type: content_type_for(path)
    )
  end

  def preview_filename(path)
    basename = File.basename(path)
    return basename if basename.present?

    "job_#{@job.id}_preview.png"
  end

  def content_type_for(path)
    case File.extname(path).downcase
    when '.png'  then 'image/png'
    when '.webp' then 'image/webp'
    else 'image/jpeg'
    end
  end
end
