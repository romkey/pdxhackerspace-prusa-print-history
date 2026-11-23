# Decides whether a bearer token may make a request. Every refusal carries a reason for the
# log, but callers show clients one generic message so a token's state cannot be probed.
class ApiTokenAuthenticator
  Result = Data.define(:token, :user, :access_level, :failure) do
    def success?
      failure.nil?
    end
  end

  # HTTP methods mapped to the access level they need.
  METHOD_LEVELS = {
    'GET' => 'read', 'HEAD' => 'read',
    'POST' => 'read_write', 'PUT' => 'read_write', 'PATCH' => 'read_write',
    'DELETE' => 'read_write_delete'
  }.freeze

  def self.call(...)
    new(...).call
  end

  def self.level_for_method(method)
    METHOD_LEVELS.fetch(method.to_s.upcase, 'read_write_delete')
  end

  def initialize(secret:, ip:, at: Time.current)
    @secret = secret
    @ip = ip
    @at = at
  end

  def call
    return failure(:api_disabled) unless Setting.api_enabled?

    token = ApiToken.authenticate_secret(@secret)
    return failure(:unknown_token) if token.nil?

    reason = refusal_for(token)
    return failure(reason, token) if reason

    token.record_use!(@ip, at: @at)
    # A device token acts as no one; it can only read and start kiosk sessions.
    user = token.device? ? nil : token.user
    Result.new(token:, user:, access_level: ApiTokenRules.effective_level(token), failure: nil)
  end

  private

  def refusal_for(token)
    return :"token_#{token.state(@at)}" unless token.active?(@at)
    return :address_not_allowed unless token.allows_ip?(@ip)
    return :external_network if Setting.api_require_internal_network? && InternalNetworks.exclude?(@ip)

    :login_too_old if !token.device? && ApiTokenRules.login_too_old?(token.user, at: @at)
  end

  def failure(reason, token = nil)
    Result.new(token:, user: nil, access_level: nil, failure: reason)
  end
end
