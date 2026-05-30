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
    @prusa_untrained_message = Setting.prusa_untrained_message
    @prusa_trained_account_message = Setting.prusa_trained_account_message
  end

  def update
    settings = params[:settings] || {}

    Setting.default_ambient_sensor = settings[:default_ambient_sensor]
    Setting.dashboard_heading = settings[:dashboard_heading]
    Setting.footer_text = settings[:footer_text]
    Setting.footer_link_label = settings[:footer_link_label]
    Setting.footer_link_url = settings[:footer_link_url]
    Setting.prusa_untrained_message = settings[:prusa_untrained_message]
    Setting.prusa_trained_account_message = settings[:prusa_trained_account_message]
    redirect_to settings_path, notice: 'Settings saved.'
  end
end
