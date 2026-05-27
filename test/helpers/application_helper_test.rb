require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  test 'app_version reads VERSION file when APP_VERSION is unset' do
    with_env('APP_VERSION' => nil) do
      assert_equal Rails.root.join('VERSION').read.strip, app_version
    end
  end

  test 'app_version prefers APP_VERSION environment variable' do
    with_env('APP_VERSION' => '9.9.9') do
      assert_equal '9.9.9', app_version
    end
  end

  test 'github_repo_url points at the project repository' do
    assert_equal 'https://github.com/romkey/pdxhackerspace-prusa-print-history', github_repo_url
  end

  private

  def with_env(vars)
    original = vars.to_h { |key, _| [key, ENV.fetch(key, nil)] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
