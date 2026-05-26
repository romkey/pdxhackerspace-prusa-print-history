issuer = ENV.fetch('AUTHENTIK_ISSUER', nil)

Rails.application.config.middleware.use OmniAuth::Builder do
  if issuer.present?
    provider :openid_connect,
             name: :authentik,
             scope: %i[openid email profile],
             response_type: :code,
             discovery: true,
             issuer: issuer,
             client_options: {
               identifier: ENV.fetch('AUTHENTIK_CLIENT_ID', nil),
               secret: ENV.fetch('AUTHENTIK_CLIENT_SECRET', nil),
               redirect_uri: ENV.fetch('AUTHENTIK_REDIRECT_URI', nil)
             }
  end

  provider :developer, fields: %i[email name], uid_field: :email if Rails.env.local?
end

OmniAuth.config.logger = Rails.logger

OmniAuth.config.on_failure = proc do |env|
  SessionsController.action(:failure).call(env)
end

if Rails.env.test?
  OmniAuth.config.test_mode = true
  OmniAuth.config.allowed_request_methods = %i[get post]
end
