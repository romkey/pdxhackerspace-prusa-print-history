module ApplicationHelper
  include Pagy::Frontend
  include Chartkick::Helper

  FLASH_CLASSES = {
    'notice' => 'success',
    'success' => 'success',
    'alert' => 'warning',
    'warning' => 'warning',
    'error' => 'danger',
    'danger' => 'danger',
    'info' => 'info'
  }.freeze

  def bootstrap_class_for(flash_type)
    FLASH_CLASSES.fetch(flash_type.to_s, 'info')
  end

  def app_version
    @app_version ||= Rails.root.join('VERSION').read.strip
  rescue Errno::ENOENT
    'unknown'
  end

  def job_eta_label(job)
    return nil unless job&.estimated_finish_at

    if job.estimated_finish_at <= Time.current
      'finishing soon'
    else
      "Done in #{distance_of_time_in_words(Time.current, job.estimated_finish_at)}"
    end
  end

  GITHUB_REPO_URL = 'https://github.com/romkey/pdxhackerspace-prusa-print-history'.freeze

  def github_repo_url
    GITHUB_REPO_URL
  end

  def storage_blob_path(attachment)
    rails_blob_path(attachment, only_path: true)
  end
end
