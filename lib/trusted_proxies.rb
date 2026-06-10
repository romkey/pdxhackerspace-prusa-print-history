module TrustedProxies
  DEFAULT_CIDRS = %w[
    10.0.0.0/8
    172.16.0.0/12
    192.168.0.0/16
    127.0.0.0/8
    fc00::/7
  ].freeze

  module_function

  def list
    @list ||= parse(ENV.fetch('TRUSTED_PROXY_CIDRS', DEFAULT_CIDRS.join(',')))
  end

  def reset!
    @list = nil
  end

  def parse(value)
    value.to_s
         .split(/[\s,]+/)
         .map(&:strip)
         .reject(&:empty?)
         .filter_map { |cidr| network_from(cidr) }
         .freeze
  end

  def network_from(cidr)
    IPAddr.new(cidr)
  rescue IPAddr::InvalidAddressError
    Rails.logger.warn("Ignoring invalid TRUSTED_PROXY_CIDRS entry: #{cidr}") if defined?(Rails)
    nil
  end
  private_class_method :network_from
end
