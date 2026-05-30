require 'test_helper'

class AppTlsConfigTest < ActiveSupport::TestCase
  teardown do
    %w[APP_PROTOCOL RAILS_ASSUME_SSL SESSION_COOKIE_SECURE].each { |key| ENV.delete(key) }
  end

  test 'defaults to plain HTTP settings' do
    assert_not AppTlsConfig.https?
    assert_not AppTlsConfig.assume_ssl?
    assert_not AppTlsConfig.secure_session_cookies?
  end

  test 'HTTPS app protocol enables secure session defaults' do
    ENV['APP_PROTOCOL'] = 'https'

    assert AppTlsConfig.https?
    assert AppTlsConfig.assume_ssl?
    assert AppTlsConfig.secure_session_cookies?
  end

  test 'explicit env vars override HTTPS defaults' do
    ENV['APP_PROTOCOL'] = 'https'
    ENV['RAILS_ASSUME_SSL'] = 'false'
    ENV['SESSION_COOKIE_SECURE'] = 'false'

    assert AppTlsConfig.https?
    assert_not AppTlsConfig.assume_ssl?
    assert_not AppTlsConfig.secure_session_cookies?
  end
end
