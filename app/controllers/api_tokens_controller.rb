# Web UI for API tokens. Members see and manage their own tokens; admins see and manage
# everyone's and can issue tokens for any user. A new or rotated secret is rendered straight
# into the response (never redirected through the flash) and cannot be shown again.
class ApiTokensController < ApplicationController
  STATE_FILTERS = ApiToken::STATES

  before_action :require_login
  before_action :set_token, only: %i[show pause resume renew rotate revoke]

  def index
    @tokens = filtered_tokens.includes(:user, :created_by).recent
    @state = params[:state].to_s.presence_in(STATE_FILTERS)
    @tokens = @tokens.select { |token| token.state == @state } if @state
    @can_create = ApiTokenRules.can_create_any?(current_user)
  end

  def show
    render_show
  end

  def new
    return head(:forbidden) unless ApiTokenRules.can_create_any?(current_user)

    @owner = owner_from_params
    @token = ApiToken.new(user: @owner, access_level: ApiTokenRules.levels_for(@owner).last)
    @expires_in_days = ApiTokenRules.default_days_for(@owner)
  end

  def create
    @owner = owner_from_params
    @token = lifecycle.issue!(owner: @owner, **token_params)
    @secret = @token.secret
    render_show
  rescue ApiTokenLifecycle::Error => e
    @token = ApiToken.new(user: @owner, name: token_params[:name], access_level: token_params[:access_level])
    @token.allowed_cidrs_text = token_params[:allowed_cidrs_text]
    @expires_in_days = token_params[:expires_in_days]
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_content
  end

  def pause = change(:pause!, 'Token paused.')
  def resume = change(:resume!, 'Token resumed.')
  def renew = change(:renew!, 'Token renewed.')
  def revoke = change(:revoke!, 'Token revoked.')

  def rotate
    lifecycle.rotate!(@token)
    @secret = @token.secret
    flash.now[:notice] = 'Token rotated. The old secret no longer works.'
    render_show
  rescue ApiTokenLifecycle::Error => e
    redirect_to api_token_path(@token), alert: e.message
  end

  private

  def set_token
    @token = ApiToken.find(params.expect(:id))
    head :forbidden unless ApiTokenRules.can_manage?(current_user, @token)
  end

  def filtered_tokens
    return current_user.api_tokens unless admin?

    params[:user_id].present? ? ApiToken.where(user_id: params[:user_id]) : ApiToken.all
  end

  def owner_from_params
    return current_user unless admin?

    User.find_by(id: params[:user_id] || params.dig(:api_token, :user_id)) || current_user
  end

  def token_params
    params.expect(api_token: %i[name access_level expires_in_days allowed_cidrs_text]).to_h.symbolize_keys
  end

  def lifecycle
    ApiTokenLifecycle.new(actor: current_user, ip: request.remote_ip)
  end

  def change(operation, notice)
    lifecycle.public_send(operation, @token)
    redirect_to api_token_path(@token), notice:
  rescue ApiTokenLifecycle::Error => e
    redirect_to api_token_path(@token), alert: e.message
  end

  def render_show
    @events = @token.events.includes(:actor).limit(50)
    response.headers['Cache-Control'] = 'no-store' if @secret
    render :show
  end
end
