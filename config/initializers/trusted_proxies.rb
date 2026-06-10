# Trust reverse-proxy networks so X-Forwarded-Proto and X-Forwarded-For are
# honored. Without this, Rails sees plain HTTP from the container and either
# marks session cookies Secure (with assume_ssl) or fails to detect HTTPS clients.
#
# Set TRUSTED_PROXY_CIDRS to the subnet(s) of your actual reverse proxy only.
# The default includes common private Docker/LAN ranges for backward compatibility.
require Rails.root.join('lib/trusted_proxies')

Rails.application.config.action_dispatch.trusted_proxies = (
  ActionDispatch::RemoteIp::TRUSTED_PROXIES + TrustedProxies.list
)
