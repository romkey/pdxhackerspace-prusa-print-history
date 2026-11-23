module Api
  module V1
    # JSON shapes shared by API endpoints. Keys are stable; new keys may be added, existing
    # keys are not renamed within v1. Times are ISO 8601 in UTC.
    module Json
      module_function

      def time(value)
        value&.utc&.iso8601
      end

      def user(user, include_admin: false)
        return nil if user.nil?

        json = { id: user.id, display_name: user.display_name, username: user.username }
        json[:admin] = user.admin? if include_admin
        json
      end

      def token(token, effective_access_level:)
        {
          id: token.id,
          name: token.name,
          prefix: token.token_prefix,
          kind: token.kind,
          access_level: token.access_level,
          effective_access_level:,
          expires_at: time(token.expires_at)
        }
      end
    end
  end
end
