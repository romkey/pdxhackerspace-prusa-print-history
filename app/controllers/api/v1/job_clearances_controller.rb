module Api
  module V1
    # POST clears a print off the printer and records how it turned out; DELETE undoes that.
    class JobClearancesController < BaseController
      before_action :set_job

      def create
        return render_error(:conflict, 'conflict', clear_conflict_message) unless @job.clearable?
        return forbidden!('You cannot clear prints.') unless access_policy.can_clear_prints?

        result = JobClearPrintService.call(job: @job, cleared_by: current_user, outcome: params[:outcome].to_s,
                                           failure_reason: params[:failure_reason].presence,
                                           failure_detail: params[:failure_detail], **label_options)
        audit!('job.cleared', subject: @job, detail: { outcome: @job.clear_outcome })
        render json: clear_response(result)
      rescue JobClearPrintService::Error, CupsService::PrintError => e
        render_error(:unprocessable_content, 'unprocessable', e.message)
      end

      def destroy
        return forbidden!('You cannot undo a clear.') unless access_policy.can_undo_clears?
        return render_error(:conflict, 'conflict', 'This print is not cleared.') unless @job.cleared?

        @job.update!(cleared_at: nil, cleared_by: nil, clear_outcome: nil, clear_failure_reason: nil,
                     clear_failure_detail: nil)
        audit!('job.clear_undone', subject: @job)
        render json: { job: Json.job(@job, policy: access_policy) }
      end

      private

      def set_job
        @job = Job.find(params.expect(:job_id))
      end

      def clear_conflict_message
        @job.cleared? ? 'This print has already been cleared.' : 'This print cannot be cleared yet.'
      end

      # A pickup label is printed for a successful print unless the caller says otherwise.
      # When nobody asked for one explicitly and no label printer is set up, clearing goes
      # ahead without it.
      def label_options
        label_printer_id = params[:label_printer_id].presence
        label_printer = label_printer_id ? LabelPrinter.find(label_printer_id) : LabelPrinter.default
        requested = params.key?(:print_label) ? ActiveModel::Type::Boolean.new.cast(params[:print_label]) : nil
        print_label = requested.nil? ? label_printer.present? : requested
        raise JobClearPrintService::Error, 'No label printer is configured.' if print_label && label_printer.nil?

        { print_label:, label_printer: }
      end

      def clear_response(result)
        {
          job: Json.job(@job, policy: access_policy),
          label: { printed: result.cups_job_id.present?, cups_job_id: result.cups_job_id },
          notification: { email_sent: result.notification.email_sent, slack_sent: result.notification.slack_sent }
        }
      end
    end
  end
end
