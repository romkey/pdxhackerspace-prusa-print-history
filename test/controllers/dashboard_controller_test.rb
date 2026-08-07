require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous visitors anywhere can view the dashboard' do
    get root_path, headers: external_request_headers

    assert_response :success
    assert_select '.dashboard-title', text: 'PDX Hackerspace'
    assert_select '.dashboard-clock time'
    assert_select 'h1', count: 0
  end

  test 'anonymous visitors on the internal network can view the dashboard' do
    get root_path

    assert_response :success
    assert_select '.dashboard-title', text: 'PDX Hackerspace'
    assert_select '.dashboard-clock time'
    assert_select 'h1', count: 0
  end

  test 'dashboard shows configured heading above the clock' do
    Setting.dashboard_heading = 'PDX Hackerspace 3D Printers'

    get root_path

    assert_response :success
    assert_select '.dashboard-title', text: 'PDX Hackerspace 3D Printers'
    assert_select '.dashboard-clock time'
    assert_select 'h1', count: 0
  ensure
    Setting.dashboard_heading = nil
  end

  test 'dashboard shows claim and clear actions for actionable jobs' do
    job = jobs(:active_xl)
    job.update!(owner: nil)

    get root_path

    assert_select 'button[data-bs-target=?]', "##{dom_id(job, :clear_print_modal)}", text: 'Clear'
    assert_select 'form[action=?][method=?] button[type=submit]', claim_job_path(job), 'post', text: 'Claim', count: 0

    login_as(users(:viewer))
    get root_path

    assert_select 'button[data-bs-target=?]', "##{dom_id(job, :claim_modal)}", text: 'Claim'
    assert_select 'form[action=?][method=?] button[type=submit]', claim_job_path(job), 'post', text: 'Claim'
    assert_select 'form[action=?] button[type=submit]', claim_job_path(job, private: 1), text: 'Claim (private)'
    assert_select 'button[data-bs-target=?]', "##{dom_id(job, :clear_print_modal)}", text: 'Clear'
  end

  test 'dashboard idle cards show actions for last finished job' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    job = jobs(:active_xl)
    job.update!(status: 'finished', ended_at: 1.hour.ago, owner: nil, cleared_at: nil)
    jobs(:orphaned_active).update!(status: 'finished', ended_at: 2.hours.ago)

    login_as(users(:viewer))
    get root_path

    assert_select 'button[data-bs-target=?]', "##{dom_id(job, :claim_modal)}", text: 'Claim'
    assert_select 'form[action=?][method=?] button[type=submit]', claim_job_path(job), 'post', text: 'Claim'
    assert_select 'button[data-bs-target=?]', "##{dom_id(job, :clear_print_modal)}", text: 'Clear'
  end

  test 'dashboard shows filter chips' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)
    jobs(:orphaned_active).update!(status: 'finished', ended_at: 1.hour.ago)

    get root_path

    assert_response :success
    assert_select 'a.filter-chip', text: 'Idle'
    assert_select 'a.filter-chip', text: 'Printing'
    assert_select 'a.filter-chip', text: 'Attention'
    assert_select 'a.filter-chip', text: 'Offline'
    assert_select 'a.filter-chip', text: 'Available', count: 0
    assert_select 'a.filter-chip', text: 'PLA'
    assert_select 'a.filter-chip', text: 'My prints', count: 0
  end

  test 'dashboard stacks active filters and supports clear' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)
    jobs(:orphaned_active).update!(status: 'finished', ended_at: 1.hour.ago)

    get root_path, params: { filter: %w[idle PLA] }

    assert_response :success
    assert_select 'a.filter-chip.active', text: 'Idle'
    assert_select 'a.filter-chip.active', text: 'PLA'
    assert_select 'a[href=?]', root_path
    assert_select '.dashboard-printer-card', count: 1
    assert_match(/2 filters active/, response.body)
    assert_match(/Clear/, response.body)
  end

  test 'logged-in dashboard shows my prints filter chip' do
    login_as(users(:viewer))
    get root_path

    assert_response :success
    assert_select 'a.filter-chip', text: 'My prints'
  end

  test 'dashboard shows empty state when filters match nothing' do
    printers(:prusa_xl).update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    printers(:prusa_mk4).update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'attention')
    printers(:prusa_mini).update!(prusalink_key: 'secret', prusalink_reachable: false, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'printing')

    get root_path, params: { filter: ['idle'] }

    assert_response :success
    assert_match(/No printers match these filters/, response.body)
    assert_select '.dashboard-printer-card', count: 0
  end

  test 'dashboard idle cards show green dot when PrusaLink is reachable' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)

    get root_path

    assert_response :success
    assert_select '.dashboard-printer-card .status-dot.status-success', minimum: 1
  end

  test 'dashboard idle cards show red dot when PrusaLink is unreachable' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: false, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)

    get root_path

    assert_response :success
    assert_select '.dashboard-printer-card .status-dot.status-danger', minimum: 1
  end

  test 'logged-in users can view the dashboard' do
    login_as(users(:viewer))
    get root_path

    assert_response :success
  end

  test 'dashboard shows printer cards with idle status when reachable' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)
    jobs(:orphaned_active).update!(status: 'finished', ended_at: 1.hour.ago)

    get root_path

    assert_response :success
    assert_select '.dashboard-printer-card', minimum: 1
    assert_match(/idle/, response.body)
    assert_select 'a.filter-chip', text: 'Idle'
    assert_select '.dashboard-image-wrap--ready', minimum: 2
  end

  test 'dashboard printer images use printing outline while active' do
    printer = printers(:prusa_xl)
    printer.update!(operational_state: 'printing')
    jobs(:active_xl).update!(status: 'printing')

    get root_path

    assert_response :success
    assert_select '.dashboard-printer-card .dashboard-image-wrap--printing', minimum: 2
  end

  test 'dashboard printing card shows current job filename' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    jobs(:active_xl).update!(status: 'printing', filename: 'dragon.gcode', progress_percent: 42.0)
    jobs(:orphaned_active).update!(status: 'finished', ended_at: 1.hour.ago)

    get root_path

    assert_response :success
    xl_card = css_select('.dashboard-printer-card').find { |node| node.text.include?('Prusa XL') }

    assert_includes xl_card.text, 'dragon.gcode'
    assert_includes xl_card.text, 'printing'
    assert_not xl_card.text.match?(/\bavailable\b/)
  end

  test 'public dashboard hides the current job filename off the internal network' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    job = jobs(:active_xl)
    job.update!(status: 'printing', filename: 'dragon.gcode', progress_percent: 42.0)
    jobs(:orphaned_active).update!(status: 'finished', ended_at: 1.hour.ago, filename: 'bracket.gcode')

    get root_path, headers: external_request_headers

    assert_response :success
    assert_no_match(/dragon\.gcode/, response.body)
    assert_no_match(/bracket\.gcode/, response.body)
    assert_select '.dashboard-job-filename a[href=?]', job_path(job), count: 0

    xl_card = css_select('.dashboard-printer-card').find { |node| node.text.include?('Prusa XL') }

    assert_includes xl_card.text, 'printing'
  end

  test 'public dashboard hides the last job filename on idle cards off the internal network' do
    printer = printers(:prusa_mini)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')
    job = Job.create!(
      printer: printer,
      filename: 'cube.gcode',
      status: 'finished',
      started_at: 2.hours.ago,
      ended_at: 1.hour.ago
    )

    get root_path, headers: external_request_headers

    assert_response :success
    assert_no_match(/cube\.gcode/, response.body)
    assert_select '.dashboard-job-filename a[href=?]', job_path(job), count: 0

    mini_card = css_select('.dashboard-printer-card').find { |node| node.text.include?('Prusa Mini') }

    assert_includes mini_card.text, 'finished'
    assert_includes mini_card.text, 'ago'
  end

  test 'public dashboard keeps the job filename out of preview image alt text' do
    printer = printers(:prusa_mini)
    job = Job.create!(
      printer: printer,
      filename: 'cube.gcode',
      status: 'finished',
      started_at: 2.hours.ago,
      ended_at: 1.hour.ago
    )
    job.preview_image.attach(
      io: StringIO.new('preview-bytes'),
      filename: 'cube.png',
      content_type: 'image/png'
    )

    get root_path, headers: external_request_headers

    assert_response :success
    assert_no_match(/cube\.gcode/, response.body)
    assert_select 'img.dashboard-image[alt=?]', 'Preview of the print on Prusa Mini'
  end

  test 'anonymous visitors on the internal network still see job filenames' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    job = jobs(:active_xl)
    job.update!(status: 'printing', filename: 'dragon.gcode', progress_percent: 42.0)

    # No headers: the default integration test IP is inside INTERNAL_NETWORKS.
    get root_path

    assert_response :success
    assert_select '.dashboard-job-filename a[href=?]', job_path(job), text: 'dragon.gcode'
  end

  test 'logged-in visitors off the internal network still see job filenames' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    job = jobs(:active_xl)
    job.update!(status: 'printing', filename: 'dragon.gcode', progress_percent: 42.0)

    login_as(users(:viewer))
    get root_path, headers: external_request_headers

    assert_response :success
    assert_select '.dashboard-job-filename a[href=?]', job_path(job), text: 'dragon.gcode'
  end

  test 'dashboard hides filename, preview and camera photo of another users private print' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    job = jobs(:active_xl)
    job.update!(status: 'printing', filename: 'secret.gcode', progress_percent: 42.0,
                owner: users(:viewer), private: true)
    job.preview_image.attach(io: StringIO.new('preview'), filename: 'p.png', content_type: 'image/png')
    capture = job.photo_captures.create!(printer: printer, captured_at: Time.current)
    capture.image.attach(io: StringIO.new('photo'), filename: 'c.jpg', content_type: 'image/jpeg')

    login_as(users(:other_viewer))
    get root_path

    assert_response :success
    assert_no_match(/secret\.gcode/, response.body)

    xl_card = css_select('.dashboard-printer-card').find { |node| node.text.include?('Prusa XL') }

    assert_includes xl_card.text, 'printing'
    assert_empty xl_card.css('.progress-bar')
    assert_equal 2, xl_card.css('img.dashboard-image-placeholder').size
  end

  test 'dashboard shows a private print in full to its owner' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    job = jobs(:active_xl)
    job.update!(status: 'printing', filename: 'secret.gcode', progress_percent: 42.0,
                owner: users(:viewer), private: true)

    login_as(users(:viewer))
    get root_path

    assert_response :success
    assert_select '.dashboard-job-filename a[href=?]', job_path(job), text: 'secret.gcode'

    xl_card = css_select('.dashboard-printer-card').find { |node| node.text.include?('Prusa XL') }

    assert_not_empty xl_card.css('.progress-bar')
  end

  test 'dashboard shows a private print in full to admins' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    job = jobs(:active_xl)
    job.update!(status: 'printing', filename: 'secret.gcode', owner: users(:viewer), private: true)

    login_as(users(:admin))
    get root_path

    assert_response :success
    assert_select '.dashboard-job-filename a[href=?]', job_path(job), text: 'secret.gcode'
  end

  test 'dashboard job filenames are wrapped to stay within printer columns' do
    stylesheet = Rails.root.join('app/assets/stylesheets/refresh.scss').read
    defined_selectors = stylesheet.scan(/\.([\w-]+)\s*[,{]/).flatten.to_set

    assert_includes defined_selectors, 'dashboard-job-filename'
    assert_includes stylesheet, 'overflow-wrap: anywhere'
    assert_match(/\.dashboard-printer-card[\s\S]*?min-width:\s*0/, stylesheet)

    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'printing')
    long_filename = 'very_long_print_filename_that_would_overflow_without_wrapping.gcode'
    job = jobs(:active_xl)
    job.update!(status: 'printing', filename: long_filename, progress_percent: 42.0)
    jobs(:orphaned_active).update!(status: 'finished', ended_at: 1.hour.ago)

    get root_path

    assert_response :success
    assert_select '.dashboard-printer-card .dashboard-job-filename a[href=?]', job_path(job), text: long_filename
  end

  test 'dashboard printer images use attention outline for problem states' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', operational_state: 'attention', prusalink_reachable: false)

    get root_path

    assert_response :success
    assert_select '.dashboard-printer-card .dashboard-image-wrap--attention', minimum: 2
  end

  test 'dashboard shows offline status when PrusaLink is unreachable' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: false, operational_state: 'idle')
    jobs(:active_xl).update!(status: 'finished', ended_at: 1.hour.ago)

    get root_path

    assert_response :success
    xl_card = css_select('.dashboard-printer-card').find { |node| node.text.include?('Prusa XL') }

    assert_includes xl_card.text, 'offline'
    assert_select '.dashboard-printer-card .status-dot.status-danger', minimum: 1
  end

  test 'dashboard shows temperature table and material info' do
    job = jobs(:active_xl)
    job.update!(progress_percent: 20.0)
    job.telemetry_readings.create!(
      recorded_at: Time.current,
      bed_temp: 60.0,
      tool_temps: { '0' => 210.0 },
      enclosure_temp: 28.0,
      ambient_temp: 22.0
    )

    get root_path

    assert_response :success
    assert_match(/Temperatures/, response.body)
    assert_match(/60/, response.body)
    assert_match(/210/, response.body)
    assert_match(/PLA/, response.body)
    assert_match(/0\.4mm/, response.body)
  end

  test 'dashboard shows placeholder images when no photo or preview exists' do
    get root_path

    assert_response :success
    assert_select 'img[src="/images/placeholder-photo.svg"]', minimum: 1
    assert_select 'img[src="/images/placeholder-preview.svg"]', minimum: 1
  end

  test 'idle dashboard card shows last job filename, status, and completion time' do
    printer = printers(:prusa_mini)
    Job.create!(
      printer: printer,
      filename: 'cube.gcode',
      status: 'finished',
      started_at: 2.hours.ago,
      ended_at: 1.hour.ago
    )

    get root_path

    assert_response :success
    assert_select '.dashboard-printer-card', text: /cube\.gcode/
    assert_match(/finished/, response.body)
    assert_match(/ago/, response.body)
  end

  test 'idle dashboard card shows last job preview when attached' do
    printer = printers(:prusa_mini)
    job = Job.create!(
      printer: printer,
      filename: 'cube.gcode',
      status: 'finished',
      started_at: 2.hours.ago,
      ended_at: 1.hour.ago
    )
    job.preview_image.attach(
      io: StringIO.new('preview-bytes'),
      filename: 'cube.png',
      content_type: 'image/png'
    )

    get root_path

    assert_response :success
    assert_select '.dashboard-printer-card img.dashboard-image[alt=?]', 'Preview of cube.gcode'
  end

  test 'anonymous navbar off the internal network shows only sign in on the right' do
    get root_path, headers: external_request_headers

    assert_response :success
    assert_select 'ul.navbar-nav.ms-auto a.nav-link', text: 'Sign in'
    assert_select 'a.nav-link', text: 'Jobs', count: 0
    assert_select 'a.nav-link', text: 'Printers', count: 0
  end

  test 'anonymous navbar on the internal network shows jobs and printers' do
    get root_path

    assert_response :success
    assert_select 'a.nav-link', text: 'Jobs'
    assert_select 'a.nav-link', text: 'Printers'
    assert_select 'a.nav-link', text: 'My prints', count: 0
  end

  test 'logged-in navbar shows full navigation' do
    login_as(users(:viewer))
    get root_path

    assert_response :success
    assert_select 'a.nav-link', text: 'Jobs'
    assert_select 'a.nav-link', text: 'My prints'
    assert_select 'a.nav-link', text: 'Printers'
  end

  test 'layout footer shows configured text and link' do
    Setting.footer_text = 'PDX Hackerspace 3D Printing'
    Setting.footer_link_label = 'FAQ'
    Setting.footer_link_url = 'https://example.com/faq'

    get root_path

    assert_response :success
    assert_match(/PDX Hackerspace 3D Printing/, response.body)
    assert_select 'footer a[href=?]', 'https://example.com/faq', text: 'FAQ'
    assert_select 'footer a[href=?]', ApplicationHelper::PDX_HACKERSPACE_URL, text: 'PDX Hackerspace'
    assert_select 'footer a[href=?]', ApplicationHelper::GITHUB_REPO_URL, text: 'GitHub'
    assert_select 'footer a[href=?]', '/printers.json', text: 'printers.json'
  ensure
    Setting.footer_text = nil
    Setting.footer_link_label = nil
    Setting.footer_link_url = nil
  end

  test 'layout footer falls back to app name, PDX Hackerspace, and GitHub links' do
    get root_path

    assert_response :success
    assert_match(/3D Printer History v#{Regexp.escape(app_version_from_repo)}/, response.body)
    assert_select 'footer a[href=?]', ApplicationHelper::PDX_HACKERSPACE_URL, text: 'PDX Hackerspace'
    assert_select 'footer a[href=?]', ApplicationHelper::GITHUB_REPO_URL, text: 'GitHub'
  end

  test 'navbar brand uses 3D Printer History' do
    get root_path

    assert_response :success
    assert_select 'a.navbar-brand', text: /3D Printer History/
  end

  test 'layout uses 3D Printer History in title and app name meta tag' do
    get root_path

    assert_response :success
    assert_select 'title', text: '3D Printer History'
    assert_select 'meta[name=?][content=?]', 'application-name', '3D Printer History'
  end

  test 'layout uses the printer icon favicon' do
    get root_path

    assert_response :success
    assert_select 'link[rel=?][href=?]', 'icon', '/icon.svg'
    assert_select 'link[rel=?][href=?]', 'apple-touch-icon', '/icon.svg'
  end

  private

  def app_version_from_repo
    Rails.root.join('VERSION').read.strip
  end
end
