module Api
  module V1
    # Public, unauthenticated: the API reference as Markdown (for people and LLM agents alike)
    # and a small JSON index pointing at it.
    class DocsController < BaseController
      DOC_PATH = Rails.root.join('docs/api.md')

      skip_before_action :authenticate_api_token!
      skip_before_action :require_access_level!

      def index
        render json: {
          name: 'Prusa print history API',
          version: 'v1',
          docs_url: api_v1_docs_url,
          authentication: 'Send an API token as "Authorization: Bearer <token>". Create tokens from your profile menu.'
        }
      end

      def show
        render plain: DOC_PATH.read, content_type: 'text/markdown'
      end
    end
  end
end
