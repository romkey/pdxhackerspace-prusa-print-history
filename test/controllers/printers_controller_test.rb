require 'test_helper'

class PrintersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @printer = printers(:prusa_xl)
  end

  test 'index is accessible to everyone' do
    get printers_path

    assert_response :success

    login_as(users(:viewer))
    get printers_path

    assert_response :success
  end

  test 'show is accessible to everyone' do
    get printer_path(@printer)

    assert_response :success
  end

  test 'show does not render the gear icon for anonymous viewers' do
    get printer_path(@printer)

    assert_select 'a[href=?]', edit_printer_path(@printer), count: 0
  end

  test 'show renders the gear for admins' do
    login_as(users(:admin))
    get printer_path(@printer)

    assert_select 'a[href=?]', edit_printer_path(@printer)
  end

  test 'show always displays ambient temperature when available' do
    @printer.update!(ambient_temp: 21.5, environment_updated_at: 2.minutes.ago)

    get printer_path(@printer)

    assert_response :success
    assert_select '.h-section-label', text: 'Environment'
    assert_match(/21\.5.*&deg;C/m, response.body)
  end

  test 'show displays idle message when printer has no active job' do
    @printer.jobs.active.find_each do |job|
      job.update!(status: 'finished', ended_at: Time.current)
    end
    @printer.update!(operational_state: 'idle')

    get printer_path(@printer)

    assert_response :success
    assert_match(/Printer is idle/, response.body)
    assert_select '.h-section-label', text: 'Print heads used'
    assert_match(/PLA/, response.body)
  end

  test 'show subscribes to live printer updates' do
    get printer_path(@printer)

    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
  end

  test 'show renders temperature chart and print heads for active job' do
    get printer_path(@printer)

    assert_select '.h-section-label', text: 'Temperatures'
    assert_select '.h-section-label', text: 'Print heads used'
    assert_match(/T0/, response.body)
    assert_match(/PLA/, response.body)
    assert_match(/PETG/, response.body)
  end

  test 'show renders print preview and camera snapshot for active job' do
    job = jobs(:active_xl)
    job.preview_image.attach(
      io: StringIO.new('preview-bytes'),
      filename: 'preview.png',
      content_type: 'image/png'
    )
    job.camera_snapshot.attach(
      io: StringIO.new('camera-bytes'),
      filename: 'camera.jpg',
      content_type: 'image/jpeg'
    )

    get printer_path(@printer)

    assert_match(/Print preview/, response.body)
    assert_match(/Camera/, response.body)
  end

  test 'show displays PrusaLink status dot when configured' do
    @printer.update!(prusalink_key: 'secret', prusalink_reachable: true)

    get printer_path(@printer)

    assert_select '.status-dot.status-success[title=?]', 'PrusaLink connected'
  end

  test 'show displays red PrusaLink dot when unreachable' do
    @printer.update!(prusalink_key: 'secret', prusalink_reachable: false)

    get printer_path(@printer)

    assert_select '.status-dot.status-danger[title=?]', 'PrusaLink unreachable'
  end

  test 'show omits PrusaLink dot when no API key is configured' do
    @printer.update!(prusalink_key: nil)

    get printer_path(@printer)

    assert_select '.status-dot.status-success[title=?]', 'PrusaLink connected', count: 0
    assert_select '.status-dot.status-danger[title=?]', 'PrusaLink unreachable', count: 0
  end

  test 'edit masks stored PrusaLink key' do
    @printer.update!(prusalink_key: 'super-secret-key')
    login_as(users(:admin))
    get edit_printer_path(@printer)

    assert_response :success
    assert_no_match(/super-secret-key/, response.body)
    assert_select 'input[type=password][name=?]', 'printer[prusalink_key]'
    assert_match(/••••/, response.body)
  end

  test 'update keeps existing PrusaLink key when field is left blank' do
    @printer.update!(prusalink_key: 'keep-me')
    login_as(users(:admin))

    patch printer_path(@printer), params: { printer: { location: 'Lab', prusalink_key: '' } }

    assert_redirected_to printer_path(@printer)
    assert_equal 'keep-me', @printer.reload.prusalink_key
  end

  test 'new redirects anonymous users to login' do
    get new_printer_path

    assert_redirected_to login_path
  end

  test 'new is forbidden for non-admin users' do
    login_as(users(:viewer))
    get new_printer_path

    assert_response :forbidden
  end

  test 'new is permitted for admins' do
    login_as(users(:admin))
    get new_printer_path

    assert_response :success
  end

  test 'admin can create a printer' do
    login_as(users(:admin))

    assert_difference -> { Printer.count } => 1 do
      post printers_path, params: { printer: { name: 'New Printer', hostname: 'new.local' } }
    end
    assert_redirected_to printer_path(Printer.last)
  end

  test 'non-admin cannot create a printer' do
    login_as(users(:viewer))

    assert_no_difference -> { Printer.count } do
      post printers_path, params: { printer: { name: 'Nope', hostname: 'nope.local' } }
    end
    assert_response :forbidden
  end

  test 'admin can update a printer' do
    login_as(users(:admin))

    patch printer_path(@printer), params: { printer: { location: 'Garage' } }

    assert_redirected_to printer_path(@printer)
    assert_equal 'Garage', @printer.reload.location
  end

  test 'admin can delete a printer' do
    login_as(users(:admin))

    assert_difference -> { Printer.count } => -1 do
      delete printer_path(@printer)
    end
    assert_redirected_to printers_path
  end
end
