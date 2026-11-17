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
    provided = bearer_token
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(provided), Digest::SHA256.hexdigest(expected)
    )
  end

  # Plain string handling (no regex) so a hostile Authorization header can't trigger backtracking.
  def bearer_token
    scheme, token = request.authorization.to_s.split(' ', 2)
    return '' unless scheme.to_s.casecmp?('bearer')

    token.to_s.strip
  end
end
