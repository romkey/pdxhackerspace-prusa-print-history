class JobsController < ApplicationController
  before_action :require_login, only: %i[claim unclaim]
  before_action :require_admin, only: %i[update]
  before_action :set_job,       only: %i[show update claim unclaim]

  def index
    scope = base_scope.includes(:printer, :owner).recent
    scope = scope.where(printer_id: params[:printer_id]) if params[:printer_id].present?

    scope = scope.where(owner_id: current_user.id) if params[:owner] == 'me' && logged_in?

    @pagy, @jobs = pagy(scope, limit: 25)
  end

  def show
    @events            = @job.events.recent.includes(photo_attachment: :blob)
    @telemetry         = @job.telemetry_readings.ordered
    @tools             = @job.tools
    @latest_reading    = @telemetry.last
  end

  def claim
    @job.update!(owner: current_user)
    redirect_to @job, notice: 'Claimed.'
  end

  def unclaim
    if admin? || @job.owner_id == current_user.id
      @job.update!(owner: nil)
      redirect_to @job, notice: 'Released.'
    else
      head :forbidden
    end
  end

  def update
    if @job.update(job_params)
      redirect_to @job, notice: 'Updated.'
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def base_scope
    Job.all
  end

  def set_job
    @job = Job.find(params.expect(:id))
  end

  def job_params
    params.expect(job: [:owner_id])
  end
end
