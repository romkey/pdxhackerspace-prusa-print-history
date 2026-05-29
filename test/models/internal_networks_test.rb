require 'test_helper'

class InternalNetworksTest < ActiveSupport::TestCase
  teardown do
    ENV.delete('INTERNAL_NETWORKS')
    InternalNetworks.reset!
  end

  test 'parses comma- and whitespace-separated IPv4 CIDR blocks' do
    ENV['INTERNAL_NETWORKS'] = '192.168.0.0/24, 10.0.50.0/24 172.16.1.0/28'
    InternalNetworks.reset!

    assert_equal 3, InternalNetworks.list.size
  end

  test 'matches IPv4 addresses inside configured networks' do
    ENV['INTERNAL_NETWORKS'] = '192.168.0.0/24'
    InternalNetworks.reset!

    assert_includes InternalNetworks, '192.168.0.1'
    assert_includes InternalNetworks, '192.168.0.255'
    assert_not_includes InternalNetworks, '192.168.1.1'
  end

  test 'ignores invalid and non-IPv4 entries' do
    ENV['INTERNAL_NETWORKS'] = '192.168.0.0/24, not-a-network, fc00::/7'
    InternalNetworks.reset!

    assert_equal 1, InternalNetworks.list.size
    assert_includes InternalNetworks, '192.168.0.10'
    assert_not_includes InternalNetworks, '::1'
  end

  test 'blank input never matches' do
    InternalNetworks.reset!

    assert_not InternalNetworks.include?(nil)
    assert_not InternalNetworks.include?('')
    assert_not InternalNetworks.include?('192.168.0.1')
  end
end
