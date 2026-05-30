require 'test_helper'

class StatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV['INTERNAL_NETWORKS'] = '192.168.0.0/24'
    InternalNetworks.reset!
    @job = jobs(:active_xl)
    @job.update!(progress_percent: 55.0)
  end

  teardown do
    ENV.delete('INTERNAL_NETWORKS')
    InternalNetworks.reset!
  end

  %w[printers jobs events].each do |endpoint|
    test "external anonymous users cannot access #{endpoint}.json" do
      get "/#{endpoint}.json", headers: external_request_headers

      assert_response :unauthorized
    end

    test "internal anonymous users can access #{endpoint}.json" do
      get "/#{endpoint}.json", headers: internal_request_headers

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
    end

    test "logged in users can access #{endpoint}.json from outside the internal network" do
      login_as(users(:viewer))
      get "/#{endpoint}.json", headers: external_request_headers

      assert_response :success
    end
  end

  test 'printers.json nests active job with progress' do
    get '/printers.json', headers: internal_request_headers

    body = response.parsed_body
    xl = body.find { |entry| entry['name'] == 'Prusa XL' }

    assert xl
    assert_equal @job.id, xl['job']['id']
    assert_in_delta 55.0, xl['job']['progress_percent']
  end

  test 'jobs.json returns at most one hundred jobs' do
    get '/jobs.json', headers: internal_request_headers

    body = response.parsed_body

    assert_operator body.size, :<=, 100
    assert(body.any? { |entry| entry['id'] == @job.id })
    assert body.first['printer']
  end

  test 'events.json returns at most one hundred events' do
    get '/events.json', headers: internal_request_headers

    body = response.parsed_body

    assert_operator body.size, :<=, 100
    assert(body.all? { |entry| entry['job'].is_a?(Hash) })
  end
end
