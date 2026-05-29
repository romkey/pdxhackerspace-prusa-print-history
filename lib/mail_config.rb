module MailConfig
  module_function

  def configured?
    smtp_server.present?
  end

  def smtp_server
    ENV['SMTP_SERVER'].presence
  end

  def smtp_port
    ENV.fetch('SMTP_PORT', 587).to_i
  end

  def smtp_username
    ENV['SMTP_USERNAME'].presence
  end

  def smtp_password
    ENV['SMTP_PASSWORD'].presence
  end

  def smtp_domain
    ENV['SMTP_DOMAIN'].presence || ENV.fetch('APP_HOST', 'localhost')
  end

  def smtp_authentication
    ENV.fetch('SMTP_AUTHENTICATION', 'plain')
  end

  def starttls_enabled?
    ENV.fetch('SMTP_ENABLE_STARTTLS_AUTO', 'true') == 'true'
  end

  def from_address
    ENV.fetch('MAIL_FROM', 'noreply@localhost')
  end

  def smtp_settings
    {
      address: smtp_server,
      port: smtp_port,
      domain: smtp_domain,
      user_name: smtp_username,
      password: smtp_password,
      authentication: smtp_authentication,
      enable_starttls_auto: starttls_enabled?
    }.compact
  end

  def apply!(config)
    config.action_mailer.default_options = { from: from_address }

    if configured?
      config.action_mailer.delivery_method = :smtp
      config.action_mailer.smtp_settings = smtp_settings
      config.action_mailer.raise_delivery_errors = true if Rails.env.production?
    elsif Rails.env.development?
      config.action_mailer.delivery_method = :file
      config.action_mailer.file_settings = { location: Rails.root.join('tmp/mail') }
    end
  end
end
