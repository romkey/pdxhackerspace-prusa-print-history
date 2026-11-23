module Api
  module V1
    class JobsController < BaseController
      allow_device_tokens :index, :show
      allow_kiosk_sessions :index, :show

      DEFAULT_LIMIT = 50
      MAX_LIMIT = 200
      STATES = %w[all active uncleared].freeze

      def index
        state = params[:state].to_s.presence_in(STATES) || 'all'
        jobs = filtered(scope_for(state)).includes(:printer, :owner, :cleared_by).recent.limit(limit)

        render json: { jobs: jobs.map { |job| Json.job(job, policy: access_policy) } }
      end

      def show
        job = Job.find(params.expect(:id))

        render json: { job: Json.job(job, policy: access_policy) }
      end

      private

      def scope_for(state)
        case state
        when 'active' then Job.active
        when 'uncleared' then Job.where(status: Job::ACTIVE_STATUSES + %w[finished], cleared_at: nil)
        else Job.all
        end
      end

      def filtered(scope)
        scope = scope.where(printer_id: params[:printer_id]) if params[:printer_id].present?
        scope = scope.owned_by(current_user) if ActiveModel::Type::Boolean.new.cast(params[:mine])
        scope
      end

      def limit
        requested = params[:limit].to_i
        requested.positive? ? [requested, MAX_LIMIT].min : DEFAULT_LIMIT
      end
    end
  end
end
