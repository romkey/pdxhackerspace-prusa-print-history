require 'test_helper'

module Prometheus
  class MetricsTest < ActiveSupport::TestCase
    setup { @body = Metrics.render }

    test 'includes build info and user counts' do
      assert_match(/^prusa_history_build_info\{version="[^"]+"\} 1$/, @body)
      assert_includes @body, "prusa_history_users #{User.count}\n"
      assert_includes @body, "prusa_history_admin_users #{User.where(admin: true).count}\n"
    end

    test 'reports every job status, even with zero jobs' do
      Job::STATUSES.each { |status| assert_includes @body, %(prusa_history_jobs{status="#{status}"}) }
    end

    test 'reports job counts that match the database' do
      printing = Job.where(status: 'printing').count

      assert_includes @body, %(prusa_history_jobs{status="printing"} #{printing}\n)
    end

    test 'reports every printer with state and reliability' do
      Printer.find_each do |printer|
        assert_includes @body, %(prusa_history_printer_reachable{printer="#{printer.name}"})
        assert_includes @body, %(prusa_history_printer_reliability_score{printer="#{printer.name}"})
      end
    end

    test 'counts failed prints by reason' do
      job = jobs(:active_xl)
      job.update!(status: 'finished', cleared_at: Time.current, clear_outcome: 'failed',
                  clear_failure_reason: 'spaghetti')

      assert_includes Metrics.render, %(prusa_history_job_failures{reason="spaghetti"} 1\n)
    end

    test 'still renders when Sidekiq stats are unavailable' do
      Sidekiq::Stats.stub(:new, -> { raise Redis::CannotConnectError }) do
        assert_includes Metrics.render, 'prusa_history_sidekiq_up 0'
      end
    end
  end
end
