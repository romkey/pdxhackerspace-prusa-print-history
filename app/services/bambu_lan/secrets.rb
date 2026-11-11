module BambuLan
  module Secrets
    def self.scrub(text, secret)
      value = text.to_s
      return value if secret.blank?

      value.gsub(secret.to_s, '[redacted]')
    end
  end
end
