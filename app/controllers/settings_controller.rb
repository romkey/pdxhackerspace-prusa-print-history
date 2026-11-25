class SettingsController < ApplicationController
  before_action :require_admin

  def show
    @printers           = Printer.ordered
    @prusa_connect      = PrusaConnectCredential.current
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
    enforce_claims enforce_claims_webhook_url enforce_filament_types
  ].concat(ApiSettings::KEYS.map(&:to_sym)).freeze

  def update
    settings = params[:settings] || {}

    # The page has more than one form, so only the fields a form submitted are saved.
    SETTING_FIELDS.each do |field|
      next unless settings.key?(field)

      Setting.public_send("#{field}=", settings[field])
    end
    redirect_to settings_path, notice: 'Settings saved.'
  end
end
