require 'test_helper'

class JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @job = jobs(:active_xl)
  end

  test 'index requires sign-in from outside the internal network' do
    get jobs_path, headers: external_request_headers

    assert_redirected_to login_path
  end

  test 'index is accessible on the internal network' do
    get jobs_path

    assert_response :success
  end

  test 'index hides pagination when all jobs fit on one page' do
    get jobs_path

    assert_response :success
    assert_select 'a[href*="page="]', count: 0
  end

  test 'index shows pagination when jobs span multiple pages' do
    printer = printers(:prusa_mini)
    23.times do |index|
      printer.jobs.create!(
        filename: "batch-#{index}.gcode",
        status: 'finished',
        started_at: index.hours.ago
      )
    end

    get jobs_path

    assert_response :success
    assert_select 'a[href*="page=2"]', minimum: 1
  end

  test 'index shows preview and snapshot thumbnails with placeholders when missing' do
    get jobs_path

    assert_select 'img[src="/images/placeholder-preview.svg"]', minimum: 1
    assert_select 'img[src="/images/placeholder-photo.svg"]', minimum: 1
  end

  test 'index shows preview and snapshot thumbnails when attached' do
    attach_job_photos(@job)

    get jobs_path

    assert_select "tr td img[alt='Preview of #{@job.filename}'][src^='/rails/active_storage/blobs/redirect/']"
    assert_select "tr td img[alt='Snapshot of #{@job.filename}'][src^='/rails/active_storage/blobs/redirect/']"
  end

  test 'show is accessible on the internal network' do
    get job_path(@job)

    assert_response :success
  end

  test 'show owner section shows username only' do
    @job.update!(owner: users(:viewer))
    get job_path(@job)

    assert_select '.h-section-label', text: 'Owner'
    assert_match(/vieweruser/, response.body)
    assert_no_match(/viewer@example.com/, response.body)
    assert_no_match(/UVIEWER123/, response.body)
    assert_no_match(/Slack user ID/i, response.body)
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

  test 'show renders print timeline after photos when events exist' do
    attach_job_photos(@job)
    @job.update!(status: 'attention')
    @job.events.create!(
      event_type: 'attention',
      from_status: 'printing',
      to_status: 'attention',
      occurred_at: 10.minutes.ago
    )

    get job_path(@job)

    assert_select '.h-section-label', text: 'Print timeline'
    assert_select '.job-timeline__bar'
    assert_select '.job-timeline__segment.job-timeline-segment--printing', minimum: 1
    assert_select '.job-timeline__segment.job-timeline-segment--attention', minimum: 1
    assert_select '.job-timeline__mark-label', text: 'S'
    assert_select '.job-timeline__mark-label', text: 'A'
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
    patch claim_job_path(@job), headers: external_request_headers

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

  test 'clear_print requires sign-in or admin off the internal network' do
    post clear_print_job_path(@job), params: { outcome: 'success' }, headers: external_request_headers

    assert_redirected_to login_path

    login_as(users(:viewer))
    post clear_print_job_path(@job), params: { outcome: 'success' }, headers: external_request_headers

    assert_response :forbidden
  end

  test 'admin can clear print successfully' do
    login_as(users(:admin))
    result = JobClearPrintService::Result.new(
      cups_job_id: 'DYMO-1',
      notification: JobNotificationService::Result.new(email_sent: false, slack_sent: false, errors: [])
    )
    JobClearPrintService.stub(:call, result) do
      post clear_print_job_path(@job), params: { outcome: 'success' }
    end

    assert_redirected_to job_path(@job)
    assert_match(/DYMO-1/, flash[:notice])
  end

  test 'admin can mark print failed' do
    login_as(users(:admin))
    JobClearPrintService.stub(:call, lambda { |**_kwargs|
      JobClearPrintService::Result.new(
        cups_job_id: nil,
        notification: JobNotificationService::Result.new(email_sent: false, slack_sent: false, errors: [])
      )
    }) do
      post clear_print_job_path(@job), params: { outcome: 'failed', failure_reason: 'spaghetti' }
    end

    assert_redirected_to job_path(@job)
    assert_match(/failed/i, flash[:notice])
  end

  test 'clear_print rejected for pending job' do
    job = jobs(:finished)
    job.update!(status: 'pending', ended_at: nil, cleared_at: nil)
    login_as(users(:admin))

    post clear_print_job_path(job), params: { outcome: 'success' }

    assert_redirected_to job_path(job)
    assert_match(/cannot be cleared/i, flash[:alert])
  end

  test 'show renders clear print form for admin on clearable job' do
    login_as(users(:admin))
    get job_path(@job)

    assert_select 'input[type=submit][value=?]', 'Successful, print label'
    assert_select 'input[type=submit][value=?]', 'Failed'
  end

  test 'show renders reprint label for cleared successful print' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'success',
      cleared_by: users(:admin)
    )
    login_as(users(:admin))
    get job_path(@job)

    assert_select 'input[type=submit][value=?]', 'Reprint label'
  end

  test 'show omits reprint label for cleared failed print' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'failed',
      clear_failure_reason: 'spaghetti',
      cleared_by: users(:admin)
    )
    login_as(users(:admin))
    get job_path(@job)

    assert_select 'input[type=submit][value=?]', 'Reprint label', count: 0
  end

  test 'reprint_label is admin-only' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'success',
      cleared_by: users(:admin)
    )

    post reprint_label_job_path(@job), headers: external_request_headers

    assert_redirected_to login_path
  end

  test 'admin can reprint label for cleared successful print' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'success',
      cleared_by: users(:admin)
    )
    login_as(users(:admin))

    JobLabelPrintService.stub(:call, 'DYMO-2') do
      post reprint_label_job_path(@job)
    end

    assert_redirected_to job_path(@job)
    assert_match(/DYMO-2/, flash[:notice])
  end

  test 'reprint_label rejected for failed clear' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'failed',
      clear_failure_reason: 'spaghetti',
      cleared_by: users(:admin)
    )
    login_as(users(:admin))

    post reprint_label_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_match(/cannot be reprinted/i, flash[:alert])
  end

  test 'unclear_print requires sign-in or admin off the internal network' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'success',
      cleared_by: users(:admin)
    )

    post unclear_print_job_path(@job), headers: external_request_headers

    assert_redirected_to login_path

    login_as(users(:viewer))
    post unclear_print_job_path(@job), headers: external_request_headers

    assert_response :forbidden
  end

  test 'admin can unclear a cleared print' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'failed',
      clear_failure_reason: 'spaghetti',
      cleared_by: users(:admin)
    )
    login_as(users(:admin))

    post unclear_print_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_match(/unclear/i, flash[:notice])
    @job.reload

    assert_nil @job.cleared_at
    assert_nil @job.cleared_by_id
    assert_nil @job.clear_outcome
    assert_nil @job.clear_failure_reason
    assert @job.clearable?
  end

  test 'show renders unclear print for cleared job' do
    @job.update!(
      status: 'finished',
      cleared_at: 1.hour.ago,
      clear_outcome: 'success',
      cleared_by: users(:admin)
    )
    login_as(users(:admin))
    get job_path(@job)

    assert_select 'button[type=submit]', text: 'Unclear print'
  end

  test 'unclear_print rejected for uncleared job' do
    login_as(users(:admin))

    post unclear_print_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_match(/not cleared/i, flash[:alert])
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
