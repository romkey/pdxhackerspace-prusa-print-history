issuer = ENV.fetch('AUTHENTIK_ISSUER', nil)

require Rails.root.join('lib/omniauth/strategies/authentik')

# OIDC claims parameter (JSON) — ask Authentik for admin status on each sign-in.
AUTHENTIK_CLAIMS = {
  userinfo: {
    is_admin: nil,
    trained_on: nil
  }
}.freeze

AUTHENTIK_SCOPES = %i[openid email profile slack trained_on].freeze

Rails.application.config.middleware.use OmniAuth::Builder do
  if issuer.present?
    provider :authentik,
             scope: AUTHENTIK_SCOPES,
             response_type: :code,
             discovery: true,
             issuer: issuer,
             extra_authorize_params: { claims: AUTHENTIK_CLAIMS.to_json },
             client_options: {
               identifier: ENV.fetch('AUTHENTIK_CLIENT_ID', nil),
               secret: ENV.fetch('AUTHENTIK_CLIENT_SECRET', nil),
               redirect_uri: ENV.fetch('AUTHENTIK_REDIRECT_URI', nil)
             }
  end

  provider :developer, fields: %i[email name], uid_field: :email if Rails.env.local?
end

OmniAuth.config.logger = Rails.logger

OmniAuth.config.allowed_request_methods = %i[post] unless Rails.env.test?
OmniAuth.config.silence_get_warning = true

OmniAuth.config.on_failure = proc do |env|
  SessionsController.action(:failure).call(env)
end

if Rails.env.test?
  OmniAuth.config.test_mode = true
  OmniAuth.config.allowed_request_methods = %i[get post]
end
