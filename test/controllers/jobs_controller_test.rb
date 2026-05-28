require 'test_helper'

class JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @job = jobs(:active_xl)
  end

  test 'index is accessible to everyone' do
    get jobs_path

    assert_response :success
  end

  test 'show is accessible to everyone' do
    get job_path(@job)

    assert_response :success
  end

  test 'show renders temperature chart when telemetry exists' do
    get job_path(@job)

    assert_select '.h-section-label', text: 'Temperatures'
    assert_match(/chart/i, response.body)
    assert_match(/"name":"Bed"/, response.body)
    assert_match(/"name":"Enclosure"/, response.body)
    assert_match(/"name":"Ambient"/, response.body)
    assert_match(/"name":"T0"/, response.body)
    assert_match(/"color":"#e07a5f"/, response.body)
    assert_match(/"xmin":/, response.body)
    assert_match(/"xmax":/, response.body)
  end

  test 'show renders print heads used for the job' do
    get job_path(@job)

    assert_select '.h-section-label', text: 'Print heads used'
    assert_match(/T0 · 0\.4 mm · PLA/, response.body)
    assert_match(/T1 · 0\.6 mm · HF · PETG/, response.body)
    assert_select 'td', text: 'PLA'
    assert_select 'td', text: 'PETG'
  end

  test 'show renders print preview and photo gallery when photos exist' do
    attach_job_photos(@job)

    get job_path(@job)

    assert_match(/Print preview/, response.body)
    assert_select '.h-section-label', text: 'Print photos'
    assert_match(/Start/, response.body)
    assert_match(/Finish/, response.body)
  end

  test 'show omits temperature chart when job has no telemetry' do
    job = jobs(:finished)

    get job_path(job)

    assert_select '.h-section-label', text: 'Temperatures', count: 0
  end

  test 'My prints filter shows only the current user\'s jobs' do
    login_as(users(:viewer))
    get jobs_path(owner: 'me')

    assert_response :success
    assert_select 'h1', text: /My prints/
  end

  test 'anonymous users cannot claim a job' do
    patch claim_job_path(@job)

    assert_redirected_to login_path
  end

  test 'logged-in user can claim an unowned job' do
    @job.update!(owner: nil)
    login_as(users(:viewer))

    patch claim_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_equal users(:viewer).id, @job.reload.owner_id
  end

  test 'a user can release their own claim' do
    @job.update!(owner: users(:viewer))
    login_as(users(:viewer))

    delete claim_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_nil @job.reload.owner_id
  end

  test 'a non-admin cannot release someone else\'s claim' do
    @job.update!(owner: users(:other_viewer))
    login_as(users(:viewer))

    delete claim_job_path(@job)

    assert_response :forbidden
    assert_equal users(:other_viewer).id, @job.reload.owner_id
  end

  test 'an admin can release anyone\'s claim' do
    @job.update!(owner: users(:other_viewer))
    login_as(users(:admin))

    delete claim_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_nil @job.reload.owner_id
  end

  test 'update owner is admin-only' do
    login_as(users(:viewer))
    patch job_path(@job), params: { job: { owner_id: users(:other_viewer).id } }

    assert_response :forbidden

    login_as(users(:admin))
    patch job_path(@job), params: { job: { owner_id: users(:other_viewer).id } }

    assert_redirected_to job_path(@job)
    assert_equal users(:other_viewer).id, @job.reload.owner_id
  end

  test 'print_label is admin-only' do
    post print_label_job_path(@job)

    assert_redirected_to login_path

    login_as(users(:viewer))
    post print_label_job_path(@job)

    assert_response :forbidden
  end

  test 'admin can print label for active job' do
    login_as(users(:admin))
    JobLabelPrintService.stub(:call, JobLabelPrintService::Result.new(
                                       job_id: 'DYMO-1', email_sent: false, slack_sent: false, notification_errors: []
                                     )) do
      post print_label_job_path(@job)
    end

    assert_redirected_to job_path(@job)
    assert_match(/DYMO-1/, flash[:notice])
  end

  test 'print_label rejected for pending job' do
    job = jobs(:finished)
    job.update!(status: 'pending', ended_at: nil)
    login_as(users(:admin))

    post print_label_job_path(job)

    assert_redirected_to job_path(job)
    assert_match(/in-progress or finished/i, flash[:alert])
  end

  test 'show renders print label form for admin on printable job' do
    login_as(users(:admin))
    get job_path(@job)

    assert_select 'input[type=submit][value=?]', 'Print label'
  end

  test 'show disables email notification when SMTP is not configured' do
    ENV.delete('SMTP_ADDRESS')
    ENV.delete('MAIL_HOST')
    login_as(users(:admin))
    get job_path(@job)

    assert_select 'input#notify_email[disabled]'
    assert_match(/SMTP env vars/i, response.body)
  end

  test 'admin can update owner slack handle from job page' do
    login_as(users(:admin))
    patch user_path(users(:viewer)), params: { user: { slack_handle: 'makerbot' } }

    assert_equal 'makerbot', users(:viewer).reload.slack_handle
  end

  private

  def attach_job_photos(job)
    job.preview_image.attach(
      io: StringIO.new('preview-bytes'),
      filename: 'preview.png',
      content_type: 'image/png'
    )
    start = job.photo_captures.create!(printer: job.printer, captured_at: 2.hours.ago)
    start.image.attach(io: StringIO.new('start-bytes'), filename: 'start.jpg', content_type: 'image/jpeg')
    finish = job.photo_captures.create!(printer: job.printer, captured_at: 1.hour.ago)
    finish.image.attach(io: StringIO.new('finish-bytes'), filename: 'finish.jpg', content_type: 'image/jpeg')
  end
end
