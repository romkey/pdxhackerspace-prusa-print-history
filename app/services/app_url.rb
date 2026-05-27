# Central host/protocol for URL generation outside a web request (Sidekiq, Turbo broadcasts).
class AppUrl
  def self.options
    host = ENV.fetch('APP_HOST', 'localhost')
    protocol = ENV.fetch('APP_PROTOCOL', 'http')
    options = { host: host, protocol: protocol }
    port = ENV.fetch('APP_PORT', nil)
    options[:port] = port.to_i if port.present?
    options
  end

  def self.with_url_options(&)
    ActiveStorage::Current.set(url_options: options, &)
  end
end
