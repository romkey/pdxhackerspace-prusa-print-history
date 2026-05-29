class OmniauthFailureReporter
  Result = Data.define(:user_message)

  USER_MESSAGES = {
    'invalid_credentials' => 'Authentik rejected the sign-in.',
    'csrf_detected' => 'Your sign-in session expired. Please try again.',
    'timeout' => 'Authentik did not respond in time.',
    'invalid_request' => 'The sign-in request was invalid.',
    'invalid_response' => 'Authentik returned an unexpected response.',
    'authentication_failed' => 'Authentication with Authentik failed.',
    'redirect_uri_mismatch' => 'Redirect URI does not match Authentik app settings.',
    'access_denied' => 'Sign-in was cancelled or denied.'
  }.freeze

  def self.report(request)
    new(request).report
  end

  def self.log_sign_in_error(request, error, context:)
    new(request).log_sign_in_error(error, context:)
  end

  def self.safe_error_message(error)
    message = error.message.to_s.strip
    return 'An unexpected error occurred.' if message.blank?

    message.truncate(200)
  end

  def initialize(request)
    @request = request
  end

  def report
    log_failure_details
    Result.new(user_message: user_message)
  end

  def log_sign_in_error(error, context:)
    Rails.logger.error("[auth] Sign-in #{context} error: #{error.class}: #{error.message}")
    return if error.backtrace.blank?

    Rails.logger.error(format_backtrace(error))
  end

  private

  def user_message
    headline = friendly_headline
    detail = exception_detail
    message = "Sign-in failed: #{headline}"
    return message if detail.blank? || detail == headline
    return message unless mapped_error_type?

    "#{message} #{detail}"
  end

  def friendly_headline
    USER_MESSAGES[error_type] ||
      USER_MESSAGES[params_message] ||
      exception_detail ||
      humanized_error_type ||
      'unknown error'
  end

  def mapped_error_type?
    USER_MESSAGES.key?(error_type) || USER_MESSAGES.key?(params_message)
  end

  def humanized_error_type
    type = error_type.presence || params_message.presence
    type&.tr('_', ' ')
  end

  def exception_detail
    error = omniauth_error
    return unless error.is_a?(Exception)

    self.class.safe_error_message(error)
  end

  def error_type
    env['omniauth.error.type']&.to_s
  end

  def params_message
    @request.params[:message].to_s.presence
  end

  def strategy
    strategy_obj = env['omniauth.error.strategy']
    return strategy_obj.name.to_s if strategy_obj.respond_to?(:name)

    @request.params[:strategy].presence || 'unknown'
  end

  def omniauth_error
    env['omniauth.error']
  end

  def env
    @request.env
  end

  def log_failure_details
    Rails.logger.error(failure_summary)
    log_error_source
    log_request_context
  end

  def failure_summary
    "[auth] Sign-in failed (strategy=#{strategy}, error_type=#{error_type || params_message || 'unknown'})"
  end

  def log_error_source
    if omniauth_error.is_a?(Exception)
      log_exception_details
    elsif params_message.present?
      Rails.logger.error("[auth] failure param message=#{params_message}")
    else
      Rails.logger.error('[auth] No omniauth.error or message param in request')
    end
  end

  def log_exception_details
    Rails.logger.error("[auth] #{omniauth_error.class}: #{omniauth_error.message}")
    Rails.logger.error(format_backtrace(omniauth_error)) if omniauth_error.backtrace.present?
  end

  def log_request_context
    context = {
      path: @request.fullpath,
      origin: @request.params[:origin],
      strategy: @request.params[:strategy]
    }.compact_blank
    return if context.empty?

    Rails.logger.error("[auth] request context: #{context.inspect}")
  end

  def format_backtrace(error)
    error.backtrace.first(10).map { |line| "[auth]   #{line}" }.join("\n")
  end
end
