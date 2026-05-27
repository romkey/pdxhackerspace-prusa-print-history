require 'test_helper'

class AppUrlTest < ActiveSupport::TestCase
  test 'options reads host and protocol from environment' do
    with_env('APP_HOST' => 'prusa.test', 'APP_PROTOCOL' => 'https', 'APP_PORT' => '8443') do
      assert_equal(
        { host: 'prusa.test', protocol: 'https', port: 8443 },
        AppUrl.options
      )
    end
  end

  private

  def with_env(vars)
    original = vars.keys.index_with { |key| ENV.fetch(key, nil) }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
