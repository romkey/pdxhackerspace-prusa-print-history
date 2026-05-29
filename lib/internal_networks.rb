module InternalNetworks
  module_function

  def list
    @list ||= ENV.fetch('INTERNAL_NETWORKS', '')
                 .split(/[\s,]+/)
                 .map(&:strip)
                 .reject(&:empty?)
                 .filter_map { |cidr| network_from(cidr) }
                 .freeze
  end

  def include?(ip)
    return false if ip.blank?
    return false if list.empty?

    addr = IPAddr.new(ip.to_s)
    return false unless addr.ipv4?

    list.any? { |network| network.include?(addr) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def reset!
    @list = nil
  end

  def network_from(cidr)
    network = IPAddr.new(cidr)
    return network if network.ipv4?

    Rails.logger.warn("Ignoring non-IPv4 INTERNAL_NETWORKS entry: #{cidr}") if defined?(Rails)
    nil
  rescue IPAddr::InvalidAddressError
    Rails.logger.warn("Ignoring invalid INTERNAL_NETWORKS entry: #{cidr}") if defined?(Rails)
    nil
  end
  private_class_method :network_from
end
