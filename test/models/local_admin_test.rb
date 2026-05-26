require 'test_helper'

class LocalAdminTest < ActiveSupport::TestCase
  teardown do
    ENV.delete('LOCAL_ADMIN_EMAIL')
    ENV.delete('LOCAL_ADMIN_PASSWORD')
    ENV.delete('LOCAL_ADMIN_NAME')
  end

  test 'configured? is false when env vars are missing' do
    assert_not LocalAdmin.configured?
  end

  test 'configured? is true when email and password are set' do
    ENV['LOCAL_ADMIN_EMAIL'] = 'admin@localhost'
    ENV['LOCAL_ADMIN_PASSWORD'] = 'secret'

    assert LocalAdmin.configured?
  end

  test 'authenticate returns nil for wrong credentials' do
    ENV['LOCAL_ADMIN_EMAIL'] = 'admin@localhost'
    ENV['LOCAL_ADMIN_PASSWORD'] = 'secret'

    assert_nil LocalAdmin.authenticate('wrong@localhost', 'secret')
    assert_nil LocalAdmin.authenticate('admin@localhost', 'wrong')
  end

  test 'authenticate creates an admin user on success' do
    ENV['LOCAL_ADMIN_EMAIL'] = 'admin@localhost'
    ENV['LOCAL_ADMIN_PASSWORD'] = 'secret'
    ENV['LOCAL_ADMIN_NAME'] = 'Dev Admin'

    user = LocalAdmin.authenticate('admin@localhost', 'secret')

    assert user.persisted?
    assert user.admin?
    assert_equal 'admin@localhost', user.email
    assert_equal 'Dev Admin', user.name
    assert_equal 'local', user.provider
  end

  test 'authenticate is case-insensitive for email' do
    ENV['LOCAL_ADMIN_EMAIL'] = 'Admin@Localhost'
    ENV['LOCAL_ADMIN_PASSWORD'] = 'secret'

    user = LocalAdmin.authenticate('admin@localhost', 'secret')

    assert_equal 'admin@localhost', user.email
  end

  test 'authenticate reuses the existing local admin user' do
    ENV['LOCAL_ADMIN_EMAIL'] = 'admin@localhost'
    ENV['LOCAL_ADMIN_PASSWORD'] = 'secret'

    first = LocalAdmin.authenticate('admin@localhost', 'secret')
    second = LocalAdmin.authenticate('admin@localhost', 'secret')

    assert_equal first.id, second.id
  end
end
