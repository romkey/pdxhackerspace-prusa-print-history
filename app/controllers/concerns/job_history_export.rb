# CSV download of the signed-in user's own print history, for JobsController#index.
module JobHistoryExport
  extend ActiveSupport::Concern

  private

  def require_login_for_csv
    require_login if request.format.csv?
  end

  def send_history_csv
    scope = apply_filters(base_scope.where(owner_id: current_user.id).includes(:printer).recent)
    send_data JobHistoryCsv.call(scope), type: 'text/csv; charset=utf-8',
                                         filename: "print-history-#{Date.current.iso8601}.csv"
  end
end
