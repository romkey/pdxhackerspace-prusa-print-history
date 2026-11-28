require 'test_helper'

class ClaimEnforcementWebhookTest < ActiveSupport::TestCase
  FakeHttp = Struct.new(:response, :requests) do
    def request(req)
      requests << req
      response
    end
  end

  setup do
    @job = jobs(:active_xl)
    @url = 'https://hooks.example.com/claims'
  end

  def with_http(response)
    http = FakeHttp.new(response, [])
    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) { yield http }
  end

  test 'posts a JSON notice when a print is paused' do
    with_http(Net::HTTPOK.new('1.1', '200', 'OK')) do |http|
      assert ClaimEnforcementWebhook.deliver(@job, 'paused', url: @url)

      body = JSON.parse(http.requests.first.body)

      assert_equal 'print_paused', body['event']
      assert_equal 'unclaimed', body['reason']
      assert_equal @job.printer.name, body.dig('printer', 'name')
      assert_equal 'dragon.gcode', body.dig('job', 'filename')
      assert_equal 'application/json', http.requests.first['Content-Type']
    end
  end

  test 'posts a print_cancelled notice for an unclaimed print that ran out of pauses' do
    with_http(Net::HTTPOK.new('1.1', '200', 'OK')) do |http|
      assert ClaimEnforcementWebhook.deliver(@job, 'cancelled', url: @url)

      body = JSON.parse(http.requests.first.body)

      assert_equal 'print_cancelled', body['event']
      assert_equal 'unclaimed', body['reason']
    end
  end

  test 'reports every reason a print was paused, and the filament problem' do
    @job.update!(filament_hold_reason: 'ABS needs ventilation.')

    payload = ClaimEnforcementWebhook.new(@job, 'paused', url: @url,
                                                          reasons: %w[filament_not_allowed unclaimed]).payload

    assert_equal 'filament_not_allowed', payload[:reason]
    assert_equal %w[filament_not_allowed unclaimed], payload[:reasons]
    assert_equal 'ABS needs ventilation.', payload.dig(:job, :filament_problem)
  end

  test 'leaves filename and claimant out of private prints' do
    @job.update!(private: true)

    payload = ClaimEnforcementWebhook.new(@job, 'continued', url: @url).payload

    assert_equal 'print_continued', payload[:event]
    assert_not payload[:job].key?(:filename)
    assert_not payload[:job].key?(:claimed_by)
  end

  test 'does nothing without a URL' do
    assert_not ClaimEnforcementWebhook.deliver(@job, 'paused', url: nil)
  end

  test 'raises on a failed response so the job retries' do
    with_http(Net::HTTPInternalServerError.new('1.1', '500', 'Oops')) do
      assert_raises(ClaimEnforcementWebhook::Error) { ClaimEnforcementWebhook.deliver(@job, 'paused', url: @url) }
    end
  end
end
