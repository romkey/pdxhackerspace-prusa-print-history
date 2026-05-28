require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous visitors can view the dashboard' do
    get root_path

    assert_response :success
    assert_select 'h1', text: /Prusa Print History/
    assert_select '[data-controller="clock"] time'
  end

  test 'dashboard uses configured heading' do
    Setting.dashboard_heading = 'PDX Hackerspace 3D Printers'

    get root_path

    assert_response :success
    assert_select 'h1', text: 'PDX Hackerspace 3D Printers'
  ensure
    Setting.dashboard_heading = nil
  end

  test 'logged-in users can view the dashboard' do
    login_as(users(:viewer))
    get root_path

    assert_response :success
  end

  test 'dashboard shows printer cards with state and availability' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')

    get root_path

    assert_response :success
    assert_select '.dashboard-printer-card', minimum: 1
    assert_match(/idle/, response.body)
    assert_match(/available/, response.body)
  end

  test 'dashboard shows unavailable when PrusaLink is unreachable' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: false)

    get root_path

    assert_response :success
    assert_match(/unavailable/, response.body)
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

  test 'anonymous navbar shows only dashboard brand and sign in' do
    get root_path

    assert_response :success
    assert_select 'a.nav-link', text: 'Sign in'
    assert_select 'a.nav-link', text: 'Jobs', count: 0
    assert_select 'a.nav-link', text: 'Printers', count: 0
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
  ensure
    Setting.footer_text = nil
    Setting.footer_link_label = nil
    Setting.footer_link_url = nil
  end

  test 'layout footer falls back to version and GitHub link' do
    get root_path

    assert_response :success
    assert_match(/Prusa Print History v#{Regexp.escape(app_version_from_repo)}/, response.body)
    assert_select 'footer a[href=?]', ApplicationHelper::GITHUB_REPO_URL, text: 'GitHub'
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
