require 'test_helper'

class PrusaConnectErrorSyncJobTest < ActiveJob::TestCase
  FakeClient = Struct.new(:state) do
    def configured? = true
    def printer(_uuid) = state
    def jobs(_uuid) = []
    def notifications(**) = []
  end

  setup do
    @job = Job.create!(printer: printers(:prusa_xl), filename: 'a.gcode', status: 'error')
    @job.printer.update!(prusa_connect_uuid: 'uuid-1')
    @event = @job.events.create!(event_type: 'error', to_status: 'error', occurred_at: Time.current)
  end

  test 'stores Connect detail on the event' do
    client = FakeClient.new({ 'printer_state' => 'ERROR', 'state_reason' => 'Fan 1 failed' })

    run_job(client)

    assert_equal 'Fan 1 failed', @event.reload.message
    assert_equal 'Fan 1 failed', @event.connect_detail.dig('printer', 'state_reason')
  end

  test 'retries when Connect has nothing yet' do
    client = FakeClient.new({ 'printer_state' => 'ERROR' })

    assert_enqueued_with(job: PrusaConnectErrorSyncJob) do
      run_job(client)
    end
    assert_nil @event.reload.message
  end

  private

  def run_job(client)
    PrusaConnect::ApiClient.stub(:new, client) { PrusaConnectErrorSyncJob.perform_now(@event.id) }
  end
end
