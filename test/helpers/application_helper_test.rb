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
end
