require 'test_helper'

class ClaimEnforcementTest < ActiveJob::TestCase
  class FakeClient
    attr_reader :calls
    attr_accessor :state

    def initialize(state)
      @state = state
      @calls = []
    end

    def job = { 'id' => 5, 'state' => @state }
    def status = { 'printer' => { 'state' => @state } }
    def pause_job(id) = @calls << [:pause, id]
    def resume_job(id) = @calls << [:resume, id]
  end

  setup do
    @printer = printers(:prusa_xl)
    @printer.update!(prusalink_key: 'k')
    @job = jobs(:active_xl)
    @job.update!(owner: nil)
    Setting.enforce_claims = true
  end

  test 'pauses an unclaimed print, records the hold, and notifies the webhook' do
    client = FakeClient.new('PRINTING')

    assert_enqueued_with(job: ClaimEnforcementWebhookJob, args: [@job.id, 'paused']) do
      assert ClaimEnforcement.hold_if_unclaimed!(@job, client:)
    end

    assert_equal [[:pause, 5]], client.calls
    @job.reload

    assert_equal 'paused', @job.status
    assert_predicate @job, :claim_held?
    assert_equal ClaimEnforcement::HOLD_MESSAGE, @job.events.recent.first.message
  end

  test 'leaves claimed prints alone' do
    @job.update!(owner: users(:viewer))
    client = FakeClient.new('PRINTING')

    assert_not ClaimEnforcement.hold_if_unclaimed!(@job, client:)
    assert_empty client.calls
  end

  test 'does nothing when claims are not enforced' do
    Setting.enforce_claims = false
    client = FakeClient.new('PRINTING')

    assert_not ClaimEnforcement.hold_if_unclaimed!(@job, client:)
    assert_empty client.calls
  end

  test 'a failed pause leaves the print unheld' do
    client = FakeClient.new('PRINTING')
    client.define_singleton_method(:pause_job) { |_id| raise PrinterConnection::Error, 'timeout' }

    assert_not ClaimEnforcement.hold_if_unclaimed!(@job, client:)
    assert_not @job.reload.claim_held?
  end

  test 'continues a held print once claimed and notifies the webhook' do
    @job.update!(status: 'paused', claim_hold_at: 1.minute.ago, owner: users(:viewer))
    client = FakeClient.new('PAUSED')

    assert_enqueued_with(job: ClaimEnforcementWebhookJob, args: [@job.id, 'continued']) do
      assert ClaimEnforcement.release!(@job, client:)
    end

    assert_equal [[:resume, 5]], client.calls
    assert_not @job.reload.claim_held?
  end

  test 'drops the hold without resuming when the print is no longer paused' do
    @job.update!(status: 'paused', claim_hold_at: 1.minute.ago, owner: users(:viewer))
    client = FakeClient.new('PRINTING')

    assert_no_enqueued_jobs(only: ClaimEnforcementWebhookJob) do
      assert_not ClaimEnforcement.release!(@job, client:)
    end

    assert_empty client.calls
    assert_not @job.reload.claim_held?
  end

  test 'does not continue an unclaimed print' do
    @job.update!(status: 'paused', claim_hold_at: 1.minute.ago)
    client = FakeClient.new('PAUSED')

    assert_not ClaimEnforcement.release!(@job, client:)
    assert_empty client.calls
    assert_predicate @job.reload, :claim_held?
  end
end
