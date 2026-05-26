# TLS terminates at the reverse proxy. Browsers on http:// cannot use Secure
# session cookies; disable the Origin header scheme check when it differs from
# request.base_url (common with assume_ssl or mixed-scheme access).
Rails.application.config.action_controller.forgery_protection_origin_check = false if Rails.env.production?
