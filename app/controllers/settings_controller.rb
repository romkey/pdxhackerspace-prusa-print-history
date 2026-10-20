class SettingsController < ApplicationController
  before_action :require_admin

  def show
    @printers           = Printer.ordered
    @home_assistant     = Setting.home_assistant_health
    @ambient_sensor     = Setting.default_ambient_sensor
    @dashboard_heading  = Setting.dashboard_heading
    @footer_text        = Setting.footer_text
    @footer_link_label  = Setting.footer_link_label
    @footer_link_url    = Setting.footer_link_url
    @image_retention_months = Setting.image_retention_months
    @delete_job_history = Setting.delete_job_history?
    @job_history_retention_months = Setting.job_history_retention_months
    @prusa_untrained_message = Setting.prusa_untrained_message
    @prusa_trained_account_message = Setting.prusa_trained_account_message
  end

  SETTING_FIELDS = %i[
    default_ambient_sensor dashboard_heading footer_text footer_link_label footer_link_url
    image_retention_months delete_job_history job_history_retention_months
    prusa_untrained_message prusa_trained_account_message
  ].freeze

  def update
    settings = params[:settings] || {}

    SETTING_FIELDS.each { |field| Setting.public_send("#{field}=", settings[field]) }
    redirect_to settings_path, notice: 'Settings saved.'
  end
end
