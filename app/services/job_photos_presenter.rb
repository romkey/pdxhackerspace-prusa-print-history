class JobPhotosPresenter
  attr_reader :job

  def initialize(job)
    @job = job
  end

  def progress_photos
    @progress_photos ||= job.photo_captures.progress.chronological.includes(image_attachment: :blob).to_a
  end

  def initial_photo
    progress_photos.first
  end

  def final_photo
    progress_photos.last if progress_photos.size > 1
  end

  def browse_photos
    progress_photos.size > 2 ? progress_photos[1..-2] : []
  end

  def photos?
    progress_photos.any?
  end
end
