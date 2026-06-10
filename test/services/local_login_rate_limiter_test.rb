require 'test_helper'

class LocalLoginRateLimiterTest < ActiveSupport::TestCase
  setup do
    @ip = '198.51.100.10'
    LocalLoginRateLimiter.reset!(@ip)
  end

  teardown do
    LocalLoginRateLimiter.reset!(@ip)
  end

  test 'allows attempts until the limit is reached' do
    assert_not LocalLoginRateLimiter.throttled?(@ip)

    LocalLoginRateLimiter::LIMIT.times do
      LocalLoginRateLimiter.record_failure(@ip)
    end

    assert LocalLoginRateLimiter.throttled?(@ip)
  end

  test 'reset clears recorded failures' do
    LocalLoginRateLimiter::LIMIT.times do
      LocalLoginRateLimiter.record_failure(@ip)
    end

    LocalLoginRateLimiter.reset!(@ip)

    assert_not LocalLoginRateLimiter.throttled?(@ip)
  end
end
