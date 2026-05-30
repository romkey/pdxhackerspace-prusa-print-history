require 'test_helper'

class InternalNetworkAccessTest < ActionDispatch::IntegrationTest
  setup do
    ENV['INTERNAL_NETWORKS'] = '192.168.0.0/24'
    InternalNetworks.reset!
    @job = jobs(:active_xl)
  end

  teardown do
    ENV.delete('INTERNAL_NETWORKS')
    InternalNetworks.reset!
  end

  test 'logged in users see status export links in the footer from outside the internal network' do
    login_as(users(:viewer))
    get root_path, headers: external_request_headers

    assert_response :success
    assert_select 'footer a[href=?]', '/printers.json', text: 'printers.json'
  end

  test 'external anonymous users do not see status export links in the footer' do
    get root_path, headers: external_request_headers

    assert_response :success
    assert_select 'footer a[href=?]', '/printers.json', count: 0
    assert_select 'footer a[href=?]', '/jobs.json', count: 0
    assert_select 'footer a[href=?]', '/events.json', count: 0
  end

  test 'internal anonymous users see status export links in the footer' do
    ENV['INTERNAL_NETWORKS'] = '192.168.0.0/24'
    InternalNetworks.reset!

    get root_path, headers: { 'REMOTE_ADDR' => '192.168.0.50' }

    assert_response :success
    assert_select 'footer a[href=?]', '/printers.json', text: 'printers.json'
    assert_select 'footer a[href=?]', '/jobs.json', text: 'jobs.json'
    assert_select 'footer a[href=?]', '/events.json', text: 'events.json'
  ensure
    ENV['INTERNAL_NETWORKS'] = '127.0.0.1/32'
    InternalNetworks.reset!
  end

  test 'external anonymous users can view the dashboard but not other status pages' do
    get root_path, headers: external_request_headers

    assert_response :success

    get jobs_path, headers: external_request_headers

    assert_redirected_to login_path

    get events_path, headers: external_request_headers

    assert_redirected_to login_path

    get job_path(@job), headers: external_request_headers

    assert_redirected_to login_path

    get printers_path, headers: external_request_headers

    assert_redirected_to login_path

    get printer_path(printers(:prusa_xl)), headers: external_request_headers

    assert_redirected_to login_path

    get '/printers.json', headers: external_request_headers

    assert_response :unauthorized

    get '/jobs.json', headers: external_request_headers

    assert_response :unauthorized

    get '/events.json', headers: external_request_headers

    assert_response :unauthorized
  end

  test 'internal anonymous users can view status pages' do
    get root_path, headers: internal_request_headers

    assert_response :success

    get jobs_path, headers: internal_request_headers

    assert_response :success

    get events_path, headers: internal_request_headers

    assert_response :success

    get job_path(@job), headers: internal_request_headers

    assert_response :success

    get printers_path, headers: internal_request_headers

    assert_response :success

    get '/printers.json', headers: internal_request_headers

    assert_response :success

    get '/jobs.json', headers: internal_request_headers

    assert_response :success

    get '/events.json', headers: internal_request_headers

    assert_response :success
  end

  test 'internal client IP is read from X-Forwarded-For through trusted proxy' do
    get jobs_path, headers: {
      'REMOTE_ADDR' => '10.0.0.5',
      'HTTP_X_FORWARDED_FOR' => '192.168.0.42'
    }

    assert_response :success
  end

  test 'internal anonymous users can clear prints' do
    result = JobClearPrintService::Result.new(
      cups_job_id: 'DYMO-1',
      notification: JobNotificationService::Result.new(email_sent: false, slack_sent: false, errors: [])
    )

    JobClearPrintService.stub(:call, result) do
      post clear_print_job_path(@job),
           params: { outcome: 'success' },
           headers: internal_request_headers
    end

    assert_redirected_to job_path(@job)
    assert_match(/DYMO-1/, flash[:notice])
  end

  test 'internal anonymous users still cannot claim prints' do
    patch claim_job_path(@job), headers: internal_request_headers

    assert_redirected_to login_path
  end

  test 'internal anonymous users still cannot access settings' do
    get settings_path, headers: internal_request_headers

    assert_redirected_to login_path
  end

  test 'internal anonymous navbar shows jobs and printers but not my prints' do
    get root_path, headers: internal_request_headers

    assert_response :success
    assert_select 'a.nav-link', text: 'Jobs'
    assert_select 'a.nav-link', text: 'Events'
    assert_select 'a.nav-link', text: 'Printers'
    assert_select 'a.nav-link', text: 'My prints', count: 0
    assert_select 'a.nav-link', text: 'Sign in'
  end

  test 'internal anonymous users can unclear prints' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'success',
      cleared_by: users(:admin)
    )

    post unclear_print_job_path(@job), headers: internal_request_headers

    assert_redirected_to job_path(@job)
    assert_match(/unclear/i, flash[:notice])
    assert_nil @job.reload.cleared_at
  end

  test 'internal anonymous users cannot reprint labels' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'success',
      cleared_by: users(:admin)
    )

    post reprint_label_job_path(@job), headers: internal_request_headers

    assert_redirected_to login_path
  end

  test 'external anonymous users cannot clear prints' do
    post clear_print_job_path(@job),
         params: { outcome: 'success' },
         headers: external_request_headers

    assert_redirected_to login_path
  end

  test 'internal anonymous users cannot manage label printers' do
    get label_printers_path, headers: internal_request_headers

    assert_redirected_to login_path
  end

  test 'internal anonymous users can view printer camera' do
    capture = printers(:prusa_xl).photo_captures.create!(captured_at: Time.current)
    capture.image.attach(
      io: StringIO.new('camera-bytes'),
      filename: 'camera.jpg',
      content_type: 'image/jpeg'
    )

    get camera_printer_path(printers(:prusa_xl)), headers: internal_request_headers

    assert_response :success
    assert_equal 'camera-bytes', response.body
  end

  test 'internal anonymous users see unclear print on cleared jobs' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'success',
      cleared_by: users(:admin)
    )

    get job_path(@job), headers: internal_request_headers

    assert_response :success
    assert_select 'button[type=submit]', text: 'Unclear print'
    assert_select 'input[type=submit][value=?]', 'Reprint label', count: 0
  end

  private

  def internal_request_headers
    { 'REMOTE_ADDR' => '192.168.0.50' }
  end

  def external_request_headers
    { 'REMOTE_ADDR' => '203.0.113.50' }
  end
end
