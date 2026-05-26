class SettingsController < ApplicationController
  before_action :require_admin

  def show
    @printers           = Printer.ordered
    @home_assistant     = Setting.home_assistant_health
    @ambient_sensor     = Setting.default_ambient_sensor
  end

  def update
    Setting.default_ambient_sensor = params.dig(:settings, :default_ambient_sensor)
    redirect_to settings_path, notice: 'Settings saved.'
  end
end
