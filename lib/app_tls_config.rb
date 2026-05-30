module AppTlsConfig
  module_function

  def https?
    ENV.fetch('APP_PROTOCOL', 'http') == 'https'
  end

  def assume_ssl?
    ENV.fetch('RAILS_ASSUME_SSL', https? ? 'true' : 'false') == 'true'
  end

  def secure_session_cookies?
    ENV.fetch('SESSION_COOKIE_SECURE', https? ? 'true' : 'false') == 'true'
  end
end
