module Api
  module V1
    # JSON shapes shared by API endpoints. Keys are stable; new keys may be added, existing
    # keys are not renamed within v1. Times are ISO 8601 in UTC.
    module Json
      module_function

      def time(value)
        value&.utc&.iso8601
      end

      def decimal(value)
        value&.to_f
      end

      def user(user, include_admin: false)
        return nil if user.nil?

        json = { id: user.id, display_name: user.display_name, username: user.username }
        json[:admin] = user.admin? if include_admin
        json
      end

      def token(token, effective_access_level:)
        {
          id: token.id,
          name: token.name,
          prefix: token.token_prefix,
          kind: token.kind,
          access_level: token.access_level,
          effective_access_level:,
          expires_at: time(token.expires_at)
        }
      end

      # `policy` is the caller's AccessPolicy: it decides what is visible and which actions
      # are offered, so a client can show exactly the buttons that will work.
      def printer(printer, job:, policy:)
        {
          id: printer.id,
          name: printer.name,
          model: printer.model,
          location: printer.location,
          status: printer.display_status,
          out_of_service: printer.out_of_service?,
          required_training: printer.required_training,
          enforces_claims: printer.enforces_claims?,
          enforces_filament_types: printer.enforces_filament_types?,
          job: job && self.job(job, policy:, include_printer: false)
        }
      end

      def job(job, policy:, include_printer: true)
        visible = policy.can_see_details?(job)
        json = job_core(job, visible:).merge(
          owner: visible ? user(job.owner) : nil,
          clearance: clearance(job),
          actions: actions(job, policy)
        )
        json[:printer] = { id: job.printer_id, name: job.printer.name } if include_printer
        json
      end

      def job_core(job, visible:)
        {
          id: job.id,
          status: job.status,
          filename: visible ? job.filename : nil,
          private: job.private?,
          progress_percent: visible ? decimal(job.progress_percent) : nil,
          started_at: time(job.started_at),
          ended_at: time(job.ended_at),
          estimated_finish_at: time(job.estimated_finish_at),
          claimed: job.owner_id.present?
        }
      end

      def clearance(job)
        return nil unless job.cleared?

        {
          cleared_at: time(job.cleared_at),
          outcome: job.clear_outcome,
          failure_reason: job.clear_failure_reason,
          failure_detail: job.clear_failure_detail,
          cleared_by: user(job.cleared_by)
        }
      end

      def actions(job, policy)
        {
          can_claim: policy.can_claim?(job) && job.owner_id != policy.user&.id,
          can_release_claim: policy.can_release_claim?(job),
          can_clear: policy.can_clear?(job),
          can_undo_clear: policy.can_undo_clear?(job)
        }
      end

      def service_entry(entry)
        {
          id: entry.id,
          printer_id: entry.printer_id,
          kind: entry.kind,
          summary: entry.summary,
          details: entry.details,
          occurred_at: time(entry.occurred_at),
          reported_by: user(entry.user)
        }
      end
    end
  end
end
