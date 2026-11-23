class DataRetentionCleaner
  def initialize(now: Time.current)
    @now = now
  end

  # Kiosk sessions and sign-in links are kept a day past expiry for troubleshooting.
  EXPIRED_CREDENTIAL_GRACE = 1.day

  def run!
    purge_expired_credentials
    purge_images
    purge_job_history if Setting.delete_job_history?
  end

  private

  def image_cutoff
    @now - Setting.image_retention_months.months
  end

  def history_cutoff
    @now - Setting.job_history_retention_months.months
  end

  def purge_images
    cutoff = image_cutoff
    PhotoCapture.where(captured_at: ...cutoff).find_each(&:destroy)
    JobEvent.where(occurred_at: ...cutoff).joins(:photo_attachment).find_each { |event| event.photo.purge }
    Job.where(created_at: ...cutoff).joins(:preview_image_attachment).find_each { |job| job.preview_image.purge }
  end

  def purge_expired_credentials
    cutoff = @now - EXPIRED_CREDENTIAL_GRACE
    ApiToken.where(kind: 'kiosk_session', expires_at: ...cutoff).delete_all
    LoginLink.where(expires_at: ...cutoff).delete_all
  end

  def purge_job_history
    Job.terminal.where(ended_at: ...history_cutoff).find_each(&:destroy)
  end
end
