module Api
  module V1
    # PUT claims a print for the token's owner; DELETE releases the claim.
    class JobClaimsController < BaseController
      allow_kiosk_sessions :update, :destroy

      before_action :set_job

      def update
        if access_policy.claim_refusal(@job) == :untrained
          return forbidden!(AccessPolicy::CLAIM_REFUSAL_MESSAGES[:untrained])
        end
        unless access_policy.can_claim?(@job)
          return render_error(:conflict, 'conflict', AccessPolicy::CLAIM_REFUSAL_MESSAGES[:claimed])
        end

        private_claim = ActiveModel::Type::Boolean.new.cast(params[:private]).present?
        @job.update!(owner: current_user, private: private_claim)
        audit!('job.claimed', subject: @job, detail: { private: private_claim })
        render json: { job: Json.job(@job, policy: access_policy) }
      end

      def destroy
        return render_error(:conflict, 'conflict', 'This print is not claimed.') if @job.owner_id.nil?
        unless access_policy.can_release_claim?(@job)
          return forbidden!('Only the owner or an admin can release this claim.')
        end

        previous_owner_id = @job.owner_id
        # A private print with no owner would be hidden from everyone but admins.
        @job.update!(owner: nil, private: false)
        audit!('job.claim_released', subject: @job, detail: { previous_owner_id: })
        render json: { job: Json.job(@job, policy: access_policy) }
      end

      private

      def set_job
        @job = Job.find(params.expect(:job_id))
      end
    end
  end
end
