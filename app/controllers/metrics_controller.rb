# Prometheus scrape endpoint. Authenticated only by a shared bearer token (METRICS_TOKEN),
# independent of user sessions and INTERNAL_NETWORKS. Disabled (404) when no token is configured.
class MetricsController < ApplicationController
  before_action :require_metrics_token

  def show
    render plain: Prometheus::Metrics.render, content_type: Prometheus::Exposition::CONTENT_TYPE
  end

  private

  def require_metrics_token
    expected = ENV['METRICS_TOKEN'].to_s
    return head :not_found if expected.empty?
    return if token_matches?(expected)

    response.headers['WWW-Authenticate'] = 'Bearer realm="metrics"'
    head :unauthorized
  end

  def token_matches?(expected)
    provided = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1].to_s
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(provided), Digest::SHA256.hexdigest(expected)
    )
  end
end
