require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PrusaPrintHistory
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.active_job.queue_adapter = :sidekiq

    config.generators do |g|
      g.test_framework :minitest, fixture: true
      g.helper false
      g.assets false
    end

    config.active_record.encryption.primary_key            = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY', nil)
    config.active_record.encryption.deterministic_key      = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY',
                                                                       nil)
    config.active_record.encryption.key_derivation_salt    = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT',
                                                                       nil)
    config.active_record.encryption.support_unencrypted_data = false

    config.time_zone = ENV.fetch('TIMEZONE', 'UTC')
  end
end
