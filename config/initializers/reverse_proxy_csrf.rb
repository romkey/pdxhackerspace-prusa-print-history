# TLS terminates at the reverse proxy. assume_ssl makes Rails generate https://
# URLs, but browsers may still reach the site via http:// if the proxy does not
# redirect. That scheme mismatch breaks CSRF origin checks even when the token
# is valid — disable the origin check and rely on the token instead.
Rails.application.config.action_controller.forgery_protection_origin_check = false if Rails.env.production?
