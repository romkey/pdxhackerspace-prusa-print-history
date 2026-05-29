require 'omniauth/strategies/openid_connect'

module OmniAuth
  module Strategies
    class Authentik < OpenIDConnect
      option :name, 'authentik'

      def authorize_uri
        uri = super
        AuthentikDebug.log_authorize_uri(uri)
        uri
      end
    end
  end
end
