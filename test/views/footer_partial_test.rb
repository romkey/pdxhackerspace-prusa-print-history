require 'test_helper'

class FooterPartialTest < ActionView::TestCase
  setup do
    def view.status_export_visible?
      false
    end
  end

  test 'default footer shows app name, PDX Hackerspace, and GitHub links' do
    render partial: 'shared/footer'

    assert_match(/3D Printer History v#{Regexp.escape(Rails.root.join('VERSION').read.strip)}/, rendered)
    assert_select 'footer a[href=?]', ApplicationHelper::PDX_HACKERSPACE_URL, text: 'PDX Hackerspace'
    assert_select 'footer a[href=?]', ApplicationHelper::GITHUB_REPO_URL, text: 'GitHub'
    assert_select 'footer a[href=?]', '/printers.json', count: 0
  end

  test 'footer shows status export links when visible' do
    def view.status_export_visible?
      true
    end

    render partial: 'shared/footer'

    assert_select 'footer a[href=?]', '/printers.json', text: 'printers.json'
    assert_select 'footer a[href=?]', '/jobs.json', text: 'jobs.json'
    assert_select 'footer a[href=?]', '/events.json', text: 'events.json'
  end

  test 'configured footer link appears alongside PDX Hackerspace and GitHub' do
    Setting.footer_text = 'Custom footer copy'
    Setting.footer_link_label = 'FAQ'
    Setting.footer_link_url = 'https://example.com/faq'

    render partial: 'shared/footer'

    assert_match(/Custom footer copy/, rendered)
    assert_select 'footer a[href=?]', 'https://example.com/faq', text: 'FAQ'
    assert_select 'footer a[href=?]', ApplicationHelper::PDX_HACKERSPACE_URL, text: 'PDX Hackerspace'
    assert_select 'footer a[href=?]', ApplicationHelper::GITHUB_REPO_URL, text: 'GitHub'
  ensure
    Setting.footer_text = nil
    Setting.footer_link_label = nil
    Setting.footer_link_url = nil
  end
end
