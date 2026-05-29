class JobNotificationPhoto
  def self.attachment_for(job)
    new(job).attachment
  end

  def initialize(job)
    @job = job
  end

  def attachment
    progress_image || event_image || preview_image
  end

  private

  def progress_image
    presenter = JobPhotosPresenter.new(@job)
    capture = presenter.final_photo || presenter.progress_photos.last
    capture&.image if capture&.image&.attached?
  end

  def event_image
    event = @job.events.where(event_type: %w[finished cancelled]).order(occurred_at: :desc).first
    event&.photo if event&.photo&.attached?
  end

  def preview_image
    @job.preview_image if @job.preview_image.attached?
  end
end
