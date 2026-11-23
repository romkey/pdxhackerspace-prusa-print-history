# Download of the signed-in user's own print history (CSV or JSON), for JobsController#export.
module JobHistoryExport
  extend ActiveSupport::Concern

  private

  def send_history_export
    jobs = apply_filters(base_scope.where(owner_id: current_user.id).includes(:printer).recent)
    stamp = Date.current.iso8601
    respond_to do |format|
      format.csv do
        send_data JobHistoryCsv.call(jobs), type: 'text/csv; charset=utf-8', filename: "print-history-#{stamp}.csv"
      end
      format.json do
        send_data JobHistoryJson.call(jobs), type: 'application/json', filename: "print-history-#{stamp}.json"
      end
    end
  end
end
