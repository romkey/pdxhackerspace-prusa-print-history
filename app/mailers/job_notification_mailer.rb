class JobNotificationMailer < ApplicationMailer
  def print_finished(job)
    setup_notification(job, event: :finished)
    mail(to: job.owner.email, subject: @presenter.subject)
  end

  def print_cleared(job)
    setup_notification(job, event: :cleared)
    mail(to: job.owner.email, subject: @presenter.subject)
  end

  private

  def setup_notification(job, event:)
    @job = job
    @presenter = JobNotificationPresenter.new(job, event:)
    attach_photo_if_present(job)
  end

  def attach_photo_if_present(job)
    photo = JobNotificationPhoto.attachment_for(job)
    return unless photo

    attachments[photo.filename.to_s] = {
      mime_type: photo.content_type,
      content: photo.download
    }
  end
end
