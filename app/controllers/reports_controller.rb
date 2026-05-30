class ReportsController < ApplicationController
  before_action :require_admin

  def index; end

  def printers
    load_report(:printers)
    render :report
  end

  def users
    load_report(:users)
    render :report
  end

  def filament
    load_report(:filament)
    render :report
  end

  def attention
    @rows = AttentionEventsReport.by_printer
    @chart_series = AttentionEventsReport.chart_series(@rows)
    render :attention
  end

  private

  def load_report(report_type)
    @report_type = report_type
    @rows = report_rows(report_type)
    @chart_series = PrintTimeReport.chart_series(@rows)
    @report_title = report_title(report_type)
    @report_label = report_label(report_type)
  end

  def report_rows(report_type)
    case report_type
    when :printers then PrintTimeReport.by_printer
    when :users then PrintTimeReport.by_user
    when :filament then PrintTimeReport.by_filament
    else
      raise ArgumentError, "Unknown report type: #{report_type}"
    end
  end

  def report_title(report_type)
    {
      printers: 'Print time by printer',
      users: 'Print time by user',
      filament: 'Print time by filament'
    }.fetch(report_type)
  end

  def report_label(report_type)
    {
      printers: 'Printer',
      users: 'User',
      filament: 'Filament'
    }.fetch(report_type)
  end
end
