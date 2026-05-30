require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  test 'app_version reads VERSION file' do
    assert_equal Rails.root.join('VERSION').read.strip, app_version
  end

  test 'job_eta_label describes remaining time' do
    job = jobs(:active_xl)
    job.estimated_finish_at = 45.minutes.from_now

    assert_match(/Done in/, job_eta_label(job))
  end

  test 'github_repo_url points at the project repository' do
    assert_equal 'https://github.com/romkey/pdxhackerspace-prusa-print-history', github_repo_url
  end

  test 'footer defaults use the app name' do
    assert_equal '3D Printer History', app_name
    assert_match(/^3D Printer History v/, footer_text)
  end

  test 'printer_idle_dot_class reflects PrusaLink reachability' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true)

    assert_equal 'status-success', printer_idle_dot_class(printer)

    printer.update!(prusalink_reachable: false)

    assert_equal 'status-danger', printer_idle_dot_class(printer)
  end
end
