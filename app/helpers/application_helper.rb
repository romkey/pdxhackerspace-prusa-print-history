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
    ENV.fetch('APP_VERSION') do
      Rails.root.join('VERSION').read.strip
    end
  rescue Errno::ENOENT
    'unknown'
  end

  GITHUB_REPO_URL = 'https://github.com/romkey/pdxhackerspace-prusa-print-history'.freeze

  def github_repo_url
    GITHUB_REPO_URL
  end

  def storage_blob_path(attachment)
    rails_blob_path(attachment, only_path: true)
  end
end
