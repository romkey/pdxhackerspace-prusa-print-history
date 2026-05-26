require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { 'cache-control' => "public, max-age=#{1.year.to_i}" }

  # Store uploaded files on a persistent disk volume (see config/storage.yml).
  config.active_storage.service = :production

  # --- TLS / reverse-proxy (all opt-in; HTTP works out of the box) ---
  #
  # RAILS_FORCE_SSL=true     → redirect http to https, HSTS
  # RAILS_ASSUME_SSL=true    → treat every request as SSL (URL generation only)
  # SESSION_COOKIE_SECURE    → Secure flag on session cookie (default false)
  # APP_PROTOCOL             → http or https for generated URLs (default http)
  #
  # With the defaults below, the app serves plain HTTP and HTTPS equally — useful
  # behind a reverse proxy during development. Enable RAILS_FORCE_SSL when you
  # want to require HTTPS in production.

  config.assume_ssl = ENV.fetch('RAILS_ASSUME_SSL', 'false') == 'true'

  if ENV.fetch('RAILS_FORCE_SSL', 'false') == 'true'
    config.force_ssl = true
    ssl_options = { redirect: { exclude: ->(request) { request.path == '/up' } } }
    ssl_options[:secure_cookies] = false if ENV.fetch('SESSION_COOKIE_SECURE', 'false') == 'false'
    config.ssl_options = ssl_options
  end

  config.session_store :cookie_store,
                       secure: ENV.fetch('SESSION_COOKIE_SECURE', 'false') == 'true',
                       same_site: :lax

  app_host = ENV.fetch('APP_HOST', 'example.com')
  app_protocol = ENV.fetch('APP_PROTOCOL', 'http')
  config.action_mailer.default_url_options = { host: app_host, protocol: app_protocol }
  config.default_url_options = { host: app_host, protocol: app_protocol }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [:request_id]
  config.logger   = ActiveSupport::TaggedLogging.logger($stdout)

  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')

  config.silence_healthcheck_path = '/up'

  config.active_support.report_deprecations = false

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false

  config.active_record.attributes_for_inspect = [:id]
end
