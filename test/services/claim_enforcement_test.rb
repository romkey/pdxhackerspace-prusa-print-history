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

  test 'continues a held print once claimed and notifies the webhook' do
    @job.update!(status: 'paused', claim_hold_at: 1.minute.ago, owner: users(:viewer))
    client = FakeClient.new('PAUSED')

    assert_enqueued_with(job: ClaimEnforcementWebhookJob, args: [@job.id, 'continued', ['claimed']]) do
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

  test 'does not continue a print that is also held for its filament' do
    @job.update!(status: 'paused', claim_hold_at: 1.minute.ago, filament_hold_at: 1.minute.ago,
                 filament_hold_reason: 'ABS needs ventilation.', owner: users(:viewer))
    client = FakeClient.new('PAUSED')

    assert_not ClaimEnforcement.release!(@job, client:)
    assert_empty client.calls
    assert_not @job.reload.claim_held?
    assert_predicate @job, :filament_held?
  end

  test 'does not continue an unclaimed print' do
    @job.update!(status: 'paused', claim_hold_at: 1.minute.ago)
    client = FakeClient.new('PAUSED')

    assert_not ClaimEnforcement.release!(@job, client:)
    assert_empty client.calls
    assert_predicate @job.reload, :claim_held?
  end
end
