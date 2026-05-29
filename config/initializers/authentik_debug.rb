Rails.application.config.to_prepare do
  next unless AuthentikDebug.enabled?

  OpenIDConnect.http_config do |faraday|
    faraday.use AuthentikDebug::FaradayMiddleware
  end
end
