# Settling a service log entry: resolving an open problem, and choosing
# whether a problem or repair lowers the printer's reliability score.
class ServiceEntryResolutionsController < ApplicationController
  before_action :require_login
  before_action :set_entry

  def resolve
    penalize = penalize?
    PrinterServiceLog.resolve_problem!(@entry, user: current_user, penalize:)
    redirect_back_or_to service_log_path, notice: resolve_notice(penalize)
  rescue PrinterServiceLog::Error, ActiveRecord::RecordInvalid => e
    redirect_back_or_to service_log_path, alert: e.message
  end

  def reliability
    counts = truthy?(params.expect(:counts_toward_reliability))
    PrinterServiceLog.set_reliability!(@entry, user: current_user, counts:)
    redirect_back_or_to service_log_path, notice: reliability_notice(counts)
  rescue PrinterServiceLog::Error, ActiveRecord::RecordInvalid => e
    redirect_back_or_to service_log_path, alert: e.message
  end

  private

  def set_entry
    @entry = ServiceEntry.find(params.expect(:id))
  end

  # Only an explicit falsy `penalize` skips the reliability penalty.
  def penalize?
    params[:penalize].blank? || truthy?(params[:penalize])
  end

  def resolve_notice(penalize)
    return 'Resolved the problem report.' if penalize

    'Resolved the problem report. It will not count against reliability.'
  end

  def reliability_notice(counts)
    counts ? 'The entry now counts toward reliability.' : 'The entry no longer counts against reliability.'
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
