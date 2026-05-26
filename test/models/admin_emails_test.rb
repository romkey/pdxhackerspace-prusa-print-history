require 'test_helper'

class AdminEmailsTest < ActiveSupport::TestCase
  teardown do
    ENV.delete('ADMIN_EMAILS')
    AdminEmails.reset!
  end

  test 'parses comma- and whitespace-separated emails' do
    ENV['ADMIN_EMAILS'] = "a@example.com, b@example.com\nc@example.com"
    AdminEmails.reset!

    assert_includes AdminEmails.list, 'a@example.com'
    assert_includes AdminEmails.list, 'b@example.com'
    assert_includes AdminEmails.list, 'c@example.com'
  end

  test 'matching is case-insensitive' do
    ENV['ADMIN_EMAILS'] = 'Admin@Example.com'
    AdminEmails.reset!

    assert_includes AdminEmails, 'admin@example.com'
    assert_includes AdminEmails, 'ADMIN@EXAMPLE.COM'
    assert_not AdminEmails.include?('other@example.com')
  end

  test 'blank input returns false' do
    AdminEmails.reset!

    assert_not AdminEmails.include?(nil)
    assert_not AdminEmails.include?('')
  end
end
