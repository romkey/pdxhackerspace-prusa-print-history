require Rails.root.join('lib/mail_config')

Rails.application.configure do
  MailConfig.apply!(config)
end
