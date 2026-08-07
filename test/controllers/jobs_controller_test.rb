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

  test 'index shows claim for logged-in users and clear on internal network' do
    @job.update!(owner: nil)

    get jobs_path

    assert_select 'button[data-bs-target=?]', "##{dom_id(@job, :clear_print_modal)}", text: 'Clear'
    assert_select 'form[action=?][method=?] button[type=submit]', claim_job_path(@job), 'post', text: 'Claim', count: 0

    login_as(users(:viewer))
    get jobs_path

    assert_select 'form[action=?][method=?] button[type=submit]', claim_job_path(@job), 'post', text: 'Claim'
    assert_select 'button[data-bs-target=?]', "##{dom_id(@job, :clear_print_modal)}", text: 'Clear'
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

    assert_select '.h-section-label', text: 'Current telemetry'
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

  test 'show labels telemetry section as last telemetry for finished jobs' do
    @job.update!(status: 'finished', ended_at: 1.hour.ago)

    get job_path(@job)

    assert_select '.h-section-label', text: 'Last telemetry'
    assert_select '.h-section-label', text: 'Current telemetry', count: 0
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
    assert_select '.text-12.text-secondary', text: 'Start'
    assert_select '.text-12.text-secondary', text: 'Current'
  end

  test 'show renders clear print forms on job detail page' do
    get job_path(@job)

    assert_select 'input[type=submit][value=?]', 'Successful, print label'
    assert_select 'input[type=submit][value=?]', 'Failed'
    assert_select '[data-controller=?]', 'clear-print-form'
  end

  test 'show renders timeline progress bar using estimated finish for active jobs' do
    freeze_time do
      @job.update!(
        started_at: 1.hour.ago,
        estimated_finish_at: 1.hour.from_now,
        progress_percent: 10.0
      )

      get job_path(@job)

      assert_select '.job-progress--timeline .progress-bar[style*="width: 50"]'
      assert_match(/Est\. finish/, response.body)
    end
  end

  test 'show labels latest print photo as job finish when job ended' do
    attach_job_photos(@job)
    @job.update!(status: 'finished', ended_at: 1.hour.ago)

    get job_path(@job)

    assert_select '.text-12.text-secondary', text: 'Job finish'
    assert_select '.text-12.text-secondary', text: 'Current', count: 0
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
    assert_select '.job-timeline__segment.job-timeline__segment--printing', minimum: 1
    assert_select '.job-timeline__segment.job-timeline__segment--attention', minimum: 1
    assert_select '.job-timeline__mark-letter', text: 'S'
    assert_select '.job-timeline__mark-letter', text: 'A'
    assert_select '.job-timeline__key-swatch.job-timeline__segment--printing', minimum: 1
    assert_select '.job-timeline__legend-letter', text: 'A'
    assert_select '.job-timeline__legend-letter', text: 'S'
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

  test 'claim marks the job public' do
    @job.update!(owner: nil, private: true)
    login_as(users(:viewer))

    patch claim_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_equal users(:viewer).id, @job.reload.owner_id
    assert_not @job.private?
  end

  test 'claim private marks the job private and owned' do
    @job.update!(owner: nil, private: false)
    login_as(users(:viewer))

    patch claim_job_path(@job, private: 1)

    assert_redirected_to job_path(@job)
    assert_equal users(:viewer).id, @job.reload.owner_id
    assert @job.private?
    assert_match(/private/i, flash[:notice])
  end

  test 'releasing a private print makes it public again' do
    @job.update!(owner: users(:viewer), private: true)
    login_as(users(:viewer))

    delete claim_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_nil @job.reload.owner_id
    assert_not @job.private?
  end

  test 'jobs index hides filename and owner of another users private print' do
    @job.update!(owner: users(:viewer), private: true, filename: 'secret.gcode')
    login_as(users(:other_viewer))

    get jobs_path

    assert_response :success
    assert_no_match(/secret\.gcode/, response.body)

    # The owner's name legitimately appears on their other, public jobs, so check the
    # private job's own row rather than the whole page.
    row = css_select('tbody tr').find { |tr| tr.text.include?('Private print') }

    assert row, 'expected a row for the private print'
    assert_not_includes row.text, users(:viewer).display_name
    assert_includes row.text, 'Private'
  end

  test 'jobs index shows a private print in full to its owner' do
    @job.update!(owner: users(:viewer), private: true, filename: 'secret.gcode')
    login_as(users(:viewer))

    get jobs_path

    assert_response :success
    assert_match(/secret\.gcode/, response.body)
  end

  test 'jobs index shows a private print in full to admins' do
    @job.update!(owner: users(:viewer), private: true, filename: 'secret.gcode')
    login_as(users(:admin))

    get jobs_path

    assert_response :success
    assert_match(/secret\.gcode/, response.body)
  end

  test 'job show hides filename, owner, progress, preview and photos of a private print' do
    @job.update!(owner: users(:viewer), private: true, filename: 'secret.gcode', progress_percent: 42.0)
    @job.preview_image.attach(io: StringIO.new('preview'), filename: 'p.png', content_type: 'image/png')
    capture = @job.photo_captures.create!(printer: @job.printer, captured_at: Time.current)
    capture.image.attach(io: StringIO.new('photo'), filename: 'c.jpg', content_type: 'image/jpeg')
    login_as(users(:other_viewer))

    get job_path(@job)

    assert_response :success
    assert_no_match(/secret\.gcode/, response.body)
    assert_no_match(/#{Regexp.escape(users(:viewer).display_name)}/, response.body)
    assert_select 'h1', text: 'Private print'
    assert_select '.progress-bar', count: 0
    assert_select '.h-section-label', text: 'Print photos', count: 0
    assert_match(/This print is private/, response.body)
  end

  test 'job show shows a private print in full to its owner' do
    @job.update!(owner: users(:viewer), private: true, filename: 'secret.gcode', progress_percent: 42.0)
    login_as(users(:viewer))

    get job_path(@job)

    assert_response :success
    assert_select 'h1', text: 'secret.gcode'
    assert_select '.progress-bar', minimum: 1
    assert_match(/visible only to you and admins/i, response.body)
  end

  test 'claim private button is offered on unclaimed jobs' do
    @job.update!(owner: nil)
    login_as(users(:viewer))

    get job_path(@job)

    assert_response :success
    assert_select 'form[action=?] button[type=submit]', claim_job_path(@job), text: 'Claim'
    assert_select 'form[action=?] button[type=submit]', claim_job_path(@job, private: 1),
                  text: 'Claim (private)'
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

  test 'admin can clear print without printing a receipt' do
    login_as(users(:admin))
    captured = nil
    JobClearPrintService.stub(:call, lambda { |**kwargs|
      captured = kwargs
      JobClearPrintService::Result.new(
        cups_job_id: nil,
        notification: JobNotificationService::Result.new(email_sent: false, slack_sent: false, errors: [])
      )
    }) do
      post clear_print_job_path(@job), params: { outcome: 'success', skip_label: '1' }
    end

    assert_redirected_to job_path(@job)
    assert_equal 'success', captured[:outcome]
    assert_not captured[:print_label]
    assert_match(/without a receipt/i, flash[:notice])
    assert_no_match(/Label job/, flash[:notice])
  end

  test 'clearing a print with a receipt still asks for the label to be printed' do
    login_as(users(:admin))
    captured = nil
    JobClearPrintService.stub(:call, lambda { |**kwargs|
      captured = kwargs
      JobClearPrintService::Result.new(
        cups_job_id: 'DYMO-2',
        notification: JobNotificationService::Result.new(email_sent: false, slack_sent: false, errors: [])
      )
    }) do
      post clear_print_job_path(@job), params: { outcome: 'success' }
    end

    assert_redirected_to job_path(@job)
    assert captured[:print_label]
    assert_match(/label sent/i, flash[:notice])
  end

  test 'clear print without a receipt works when no label printer is configured' do
    LabelPrinter.delete_all
    login_as(users(:admin))

    JobNotificationService.stub(:notify_print_cleared, JobNotificationService::Result.new(
                                                         email_sent: false, slack_sent: false, errors: []
                                                       )) do
      post clear_print_job_path(@job), params: { outcome: 'success', skip_label: '1' }
    end

    assert_redirected_to job_path(@job)
    assert_nil flash[:alert]
    assert @job.reload.cleared?
    assert_equal 'success', @job.clear_outcome
  end

  test 'clear print with a receipt is still refused when no label printer is configured' do
    LabelPrinter.delete_all
    login_as(users(:admin))

    post clear_print_job_path(@job), params: { outcome: 'success' }

    assert_redirected_to job_path(@job)
    assert_match(/no label printer configured/i, flash[:alert])
    assert_not @job.reload.cleared?
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
    assert_select 'input[type=submit][value=?]', 'Clear (no receipt)'
    assert_select 'input[type=submit][value=?]', 'Failed'
  end

  test 'show still offers clear without a receipt when no label printer is configured' do
    LabelPrinter.delete_all
    login_as(users(:admin))
    get job_path(@job)

    assert_select 'input[type=submit][value=?]', 'Successful, print label', count: 0
    assert_select 'input[type=submit][value=?]', 'Clear (no receipt)'
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
