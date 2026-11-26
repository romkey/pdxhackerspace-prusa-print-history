require 'test_helper'

class PrintStartHoldsTest < ActiveJob::TestCase
  class FakeClient
    attr_reader :calls

    def initialize(state = 'PRINTING')
      @state = state
      @calls = []
    end

    def job = { 'id' => 5, 'state' => @state }
    def status = { 'printer' => { 'state' => @state } }
    def pause_job(id) = @calls << [:pause, id]
  end

  setup do
    @printer = printers(:prusa_xl)
    @printer.update!(prusalink_key: 'k', hardened_nozzle: false, ventilation: false)
    @job = jobs(:active_xl)
    @job.update!(owner: nil)
    @job.tools.destroy_all
  end

  def add_tool(material, index: 0)
    @job.tools.create!(tool_index: index, nozzle_size_mm: 0.4, material:)
  end

  test 'pauses an unclaimed print while claims are enforced' do
    Setting.enforce_claims = true
    client = FakeClient.new

    assert_enqueued_with(job: ClaimEnforcementWebhookJob, args: [@job.id, 'paused', ['unclaimed']]) do
      assert PrintStartHolds.apply!(@job, client:)
    end

    assert_equal [[:pause, 5]], client.calls
    @job.reload

    assert_equal 'paused', @job.status
    assert_predicate @job, :claim_held?
    assert_not @job.filament_held?
    assert_equal PrintStartHolds::CLAIM_MESSAGE, @job.events.recent.first.message
  end

  test 'leaves a print alone on a printer exempted from both enforcement settings' do
    Setting.enforce_claims = true
    Setting.enforce_filament_types = true
    @printer.update!(enforce_claims: false, enforce_filament_types: false)
    add_tool('ABS')
    client = FakeClient.new

    assert_no_enqueued_jobs(only: ClaimEnforcementWebhookJob) do
      assert_not PrintStartHolds.apply!(@job.reload, client:)
    end
    assert_empty client.calls
    assert_not @job.reload.held?
  end

  test 'enforces only what a printer is not exempted from' do
    Setting.enforce_claims = true
    Setting.enforce_filament_types = true
    @printer.update!(enforce_claims: false)
    add_tool('ABS')

    assert PrintStartHolds.apply!(@job.reload, client: FakeClient.new)
    @job.reload

    assert_predicate @job, :filament_held?
    assert_not @job.claim_held?
  end

  test 'pauses a print whose filament the printer may not run' do
    Setting.enforce_filament_types = true
    @job.update!(owner: users(:viewer))
    add_tool('PLA', index: 0)
    add_tool('ABS', index: 1)
    client = FakeClient.new

    assert_enqueued_with(job: ClaimEnforcementWebhookJob, args: [@job.id, 'paused', ['filament_not_allowed']]) do
      assert PrintStartHolds.apply!(@job, client:)
    end

    @job.reload

    assert_predicate @job, :filament_held?
    assert_not @job.claim_held?
    assert_equal 'ABS needs ventilation.', @job.filament_hold_reason
    assert_match(/may not run this filament: ABS needs ventilation/, @job.events.recent.first.message)
  end

  test 'one pause covers both an unclaimed print and a disallowed filament' do
    Setting.enforce_claims = true
    Setting.enforce_filament_types = true
    add_tool('PAHT-CF')
    client = FakeClient.new

    assert PrintStartHolds.apply!(@job, client:)

    assert_equal 1, client.calls.size
    @job.reload

    assert_predicate @job, :claim_held?
    assert_equal 'PA-CF needs a hardened nozzle and ventilation.', @job.filament_hold_reason
  end

  test 'lets allowed and unknown filaments through' do
    Setting.enforce_filament_types = true
    @printer.update!(ventilation: true)
    add_tool('ABS', index: 0)
    add_tool('Mystery goo', index: 1)
    client = FakeClient.new

    assert_not PrintStartHolds.apply!(@job, client:)
    assert_empty client.calls
  end

  test 'does nothing when neither setting is on' do
    add_tool('ABS')
    client = FakeClient.new

    assert_not PrintStartHolds.apply!(@job, client:)
    assert_empty client.calls
  end

  test 'a failed pause leaves the print unheld' do
    Setting.enforce_claims = true
    client = FakeClient.new
    client.define_singleton_method(:pause_job) { |_id| raise PrinterConnection::Error, 'timeout' }

    assert_not PrintStartHolds.apply!(@job, client:)
    assert_not @job.reload.held?
  end
end
