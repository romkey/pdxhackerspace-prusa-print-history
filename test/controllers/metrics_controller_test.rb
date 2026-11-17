require 'test_helper'

class MetricsControllerTest < ActionDispatch::IntegrationTest
  setup { ENV['METRICS_TOKEN'] = 'secret-token' }
  teardown { ENV.delete('METRICS_TOKEN') }

  test 'returns 404 when no token is configured' do
    ENV.delete('METRICS_TOKEN')
    get '/metrics', headers: { 'Authorization' => 'Bearer secret-token' }

    assert_response :not_found
  end

  test 'rejects a missing token' do
    get '/metrics'

    assert_response :unauthorized
    assert_includes response.headers['WWW-Authenticate'], 'Bearer'
  end

  test 'rejects a wrong token' do
    get '/metrics', headers: { 'Authorization' => 'Bearer nope' }

    assert_response :unauthorized
  end

  test 'does not accept the token as a query parameter' do
    get '/metrics', params: { token: 'secret-token' }

    assert_response :unauthorized
  end

  test 'serves Prometheus text with a valid token even from outside the internal network' do
    get '/metrics', headers: external_request_headers.merge('Authorization' => 'Bearer secret-token')

    assert_response :success
    assert_match %r{\Atext/plain; version=0\.0\.4}, response.content_type
    assert_includes response.body, '# TYPE prusa_history_jobs gauge'
    assert_match(/^prusa_history_users \d+$/, response.body)
    assert_match(/^prusa_history_jobs\{status="printing"\} \d+$/, response.body)
    assert_match(/^prusa_history_jobs_within_duration\{le="\+Inf"\} \d+$/, response.body)
    assert_match(/^prusa_history_printer_reachable\{printer="Prusa XL"\} [01]$/, response.body)
  end
end
