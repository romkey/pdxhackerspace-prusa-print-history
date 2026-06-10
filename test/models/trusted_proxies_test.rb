require 'test_helper'

class TrustedProxiesTest < ActiveSupport::TestCase
  teardown do
    ENV.delete('TRUSTED_PROXY_CIDRS')
    TrustedProxies.reset!
  end

  test 'defaults to common private and docker proxy ranges' do
    TrustedProxies.reset!

    assert(TrustedProxies.list.any? { |network| network.include?(IPAddr.new('10.0.0.5')) })
    assert(TrustedProxies.list.any? { |network| network.include?(IPAddr.new('192.168.0.50')) })
  end

  test 'parses comma-separated CIDR blocks from env' do
    ENV['TRUSTED_PROXY_CIDRS'] = '10.0.0.0/8, 172.18.0.0/16'
    TrustedProxies.reset!

    assert_equal 2, TrustedProxies.list.size
    assert(TrustedProxies.list.any? { |network| network.include?(IPAddr.new('10.1.2.3')) })
    assert(TrustedProxies.list.any? { |network| network.include?(IPAddr.new('172.18.4.5')) })
  end

  test 'ignores invalid entries' do
    ENV['TRUSTED_PROXY_CIDRS'] = 'not-a-cidr,10.0.0.0/8'
    TrustedProxies.reset!

    assert_equal 1, TrustedProxies.list.size
    assert_includes TrustedProxies.list.first, IPAddr.new('10.0.0.1')
  end
end
