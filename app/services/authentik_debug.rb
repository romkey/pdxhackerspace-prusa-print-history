module AuthentikDebug
  REDACTED = '[REDACTED]'.freeze
  REDACT_KEYS = %w[
    client_secret
    secret
    access_token
    refresh_token
    id_token
    token
    code
    password
  ].freeze

  module_function

  def enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('AUTHENTIK_DEBUG', nil))
  end

  def log_authorize_uri(uri)
    return unless enabled?

    parsed = URI.parse(uri.to_s)
    params = Rack::Utils.parse_nested_query(parsed.query)
    params['claims'] = parse_json(params['claims']) if params['claims'].is_a?(String)
    parsed.query = nil
    parsed.fragment = nil

    log_outbound('GET', parsed.to_s, params)
  end

  def log_auth_hash(auth)
    return unless enabled?

    payload = {
      provider: auth.provider,
      uid: auth.uid,
      info: hashify(auth.info),
      extra: { raw_info: hashify(auth.extra&.raw_info) },
      credentials: redact(hashify(auth.credentials))
    }

    log_inbound('omniauth.auth', payload)
  end

  def log_http_request(env)
    log_outbound(env.method.to_s.upcase, env.url.to_s, env.body)
  end

  def log_http_response(env)
    log_inbound("#{env.status} #{env.method.to_s.upcase} #{env.url}", env.body)
  end

  def log_outbound(method, url, payload)
    return unless enabled?

    body = format_payload(payload)
    location = [method, sanitize_url(url)].compact.join(' ').strip
    Rails.logger.info("[Authentik JSON] → #{location}\n#{body}")
  end

  def log_inbound(label, payload)
    return unless enabled?

    Rails.logger.info("[Authentik JSON] ← #{label}\n#{format_payload(payload)}")
  end

  def format_payload(payload)
    redacted = redact(normalize_payload(payload))
    return '(empty)' if redacted.nil?

    JSON.pretty_generate(redacted)
  rescue JSON::GeneratorError
    redacted.inspect
  end

  def normalize_payload(payload)
    case payload
    when Hash, Array then payload
    when String then parse_json(payload) || payload
    else
      payload.presence
    end
  end

  def parse_json(value)
    JSON.parse(value)
  rescue JSON::ParserError
    nil
  end

  def redact(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, nested), result|
        result[key] = redact_key?(key) ? REDACTED : redact(nested)
      end
    when Array
      value.map { |entry| redact(entry) }
    else
      value
    end
  end

  def redact_key?(key)
    REDACT_KEYS.include?(key.to_s.downcase)
  end

  def hashify(value)
    return {} if value.nil?
    return value.to_hash if value.respond_to?(:to_hash)

    value
  end

  def sanitize_url(url)
    uri = URI.parse(url.to_s)
    uri.query = nil
    uri.fragment = nil
    uri.to_s
  rescue URI::InvalidURIError
    url.to_s
  end
end
