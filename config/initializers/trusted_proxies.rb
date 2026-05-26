# Trust reverse-proxy networks so X-Forwarded-Proto and X-Forwarded-For are
# honored. Without this, Rails sees plain HTTP from the container and either
# marks session cookies Secure (with assume_ssl) or fails to detect HTTPS clients.
Rails.application.config.action_dispatch.trusted_proxies = (
  ActionDispatch::RemoteIp::TRUSTED_PROXIES +
  %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8 fc00::/7].map { |cidr| IPAddr.new(cidr) }
)
