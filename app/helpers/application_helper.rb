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
end
