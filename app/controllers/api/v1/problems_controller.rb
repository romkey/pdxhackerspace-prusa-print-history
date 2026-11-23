module Api
  module V1
    # Files a problem report in a printer's service log, as the token's owner.
    class ProblemsController < BaseController
      allow_kiosk_sessions :create

      def create
        printer = Printer.find(params.expect(:printer_id))
        entry = PrinterServiceLog.report_problem!(printer:, user: current_user, **problem_attributes)
        detail = { printer_id: printer.id, take_out_of_service: problem_attributes[:take_out_of_service] }
        audit!('printer.problem_reported', subject: entry, detail:)
        render json: { problem: Json.service_entry(entry), printer_out_of_service: printer.reload.out_of_service? },
               status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(:unprocessable_content, 'unprocessable', e.record.errors.full_messages.to_sentence)
      end

      private

      def problem_attributes
        @problem_attributes ||= {
          summary: params[:summary].to_s.strip,
          details: params[:details].presence,
          take_out_of_service: ActiveModel::Type::Boolean.new.cast(params[:take_out_of_service]).present?
        }
      end
    end
  end
end
