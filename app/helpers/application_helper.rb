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
  APP_NAME = '3D Printer History'.freeze
  PDX_HACKERSPACE_URL = 'https://pdxhackerspace.org'.freeze

  def github_repo_url
    GITHUB_REPO_URL
  end

  def app_name
    APP_NAME
  end

  def pdx_hackerspace_url
    PDX_HACKERSPACE_URL
  end

  def storage_blob_path(attachment)
    rails_blob_path(attachment, only_path: true)
  end

  def dashboard_heading
    Setting.dashboard_heading.presence || 'PDX Hackerspace'
  end

  def footer_text
    Setting.footer_text.presence || "#{APP_NAME} v#{app_version}"
  end

  def status_export_visible?
    logged_in? || internal_network?
  end

  def printer_status_dot_class(printer)
    printer.prusalink_connection_status == :reachable ? 'status-success' : 'status-danger'
  end

  def printer_status_label(printer)
    return 'unavailable' unless printer.prusalink_connection_status == :reachable

    printer.display_status
  end

  def printer_idle_dot_class(printer)
    printer_status_dot_class(printer)
  end

  def dashboard_temp_label(value)
    return 'n/a' if value.blank?

    value.to_f.round(0).to_s
  end
end
