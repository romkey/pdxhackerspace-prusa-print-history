require 'test_helper'

class PrintersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @printer = printers(:prusa_xl)
  end

  test 'index requires sign-in from outside the internal network' do
    get printers_path, headers: external_request_headers

    assert_redirected_to login_path
  end

  test 'index is accessible on the internal network' do
    get printers_path

    assert_response :success

    login_as(users(:viewer))
    get printers_path

    assert_response :success
  end

  test 'show is accessible on the internal network' do
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

  test 'show hides integrations from anonymous viewers' do
    get printer_path(@printer)

    assert_response :success
    assert_select '.h-section-label', text: 'Integrations', count: 0
  end

  test 'show hides integrations from non-admin users' do
    login_as(users(:viewer))
    get printer_path(@printer)

    assert_response :success
    assert_select '.h-section-label', text: 'Integrations', count: 0
  end

  test 'show shows integrations to admins' do
    login_as(users(:admin))
    get printer_path(@printer)

    assert_response :success
    assert_select '.h-section-label', text: 'Integrations'
    assert_match(/PrusaLink/, response.body)
  end

  test 'show displays Prusa Connect integration status to admins' do
    @printer.update!(prusa_connect_token: 'camera-token-12345678')
    login_as(users(:admin))
    get printer_path(@printer)

    assert_response :success
    assert_match(/Prusa Connect configured/, response.body)
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
    assert_select '.h-section-label', text: 'Previous job'
    assert_match(/Printer is idle/, response.body)
    assert_select '.h-section-label', text: 'Print heads'
    assert_match(/PLA/, response.body)
  end

  test 'show labels current job section for active prints' do
    get printer_path(@printer)

    assert_select '.h-section-label', text: 'Current job'
  end

  test 'show subscribes to live printer updates' do
    get printer_path(@printer)

    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
  end

  test 'show renders temperature chart and print heads for active job' do
    get printer_path(@printer)

    assert_select '.h-section-label', text: 'Temperatures'
    assert_select '.h-section-label', text: 'Print heads'
    assert_match(/T0/, response.body)
    assert_match(/PLA/, response.body)
    assert_match(/PETG/, response.body)
  end

  test 'show renders camera section when camera is configured' do
    get printer_path(@printer)

    assert_select '.h-section-label', text: 'Camera'
    assert_select 'img[src^=?]', camera_printer_path(@printer)
  end

  test 'show omits camera section when printer has no camera URL' do
    printer = printers(:prusa_mk4)
    printer.update!(prusalink_key: 'secret')

    get printer_path(printer)

    assert_response :success
    assert_select '.h-section-label', text: 'Camera', count: 0
  end

  test 'camera endpoint serves stored photo when available' do
    capture = @printer.photo_captures.create!(captured_at: Time.current)
    capture.image.attach(
      io: StringIO.new('STORED-BYTES'),
      filename: 'stored.jpg',
      content_type: 'image/jpeg'
    )

    get camera_printer_path(@printer)

    assert_response :success
    assert_equal 'image/jpeg', response.media_type
    assert_equal 'STORED-BYTES', response.body
  end

  test 'camera endpoint is refused while another users private print is on the bed' do
    attach_private_print_capture

    login_as(users(:other_viewer))
    get camera_printer_path(@printer)

    assert_response :forbidden
  end

  test 'camera endpoint is refused for anonymous internal viewers during a private print' do
    attach_private_print_capture

    get camera_printer_path(@printer)

    assert_response :forbidden
  end

  test 'camera endpoint serves a private print to its owner and to admins' do
    attach_private_print_capture

    login_as(users(:viewer))
    get camera_printer_path(@printer)

    assert_response :success

    login_as(users(:admin))
    get camera_printer_path(@printer)

    assert_response :success
  end

  test 'camera endpoint proxies configured camera URL when no stored photo' do
    snapshot = {
      io: StringIO.new('JPEG-BYTES'),
      filename: 'camera.jpg',
      content_type: 'image/jpeg'
    }

    PrinterCamera.stub(:snapshot, snapshot) do
      get camera_printer_path(@printer)
    end

    assert_response :success
    assert_equal 'image/jpeg', response.media_type
    assert_equal 'JPEG-BYTES', response.body
  end

  test 'camera endpoint returns service unavailable when fetch fails' do
    PrinterCamera.stub(:snapshot, nil) do
      get camera_printer_path(@printer)
    end

    assert_response :service_unavailable
  end

  test 'show renders print preview and stored camera photo for active job' do
    freeze_time do
      job = jobs(:active_xl)
      job.update!(
        started_at: 1.hour.ago,
        estimated_finish_at: 1.hour.from_now,
        progress_percent: 10.0,
        time_printing_seconds: 900
      )
      job.preview_image.attach(
        io: StringIO.new('preview-bytes'),
        filename: 'preview.png',
        content_type: 'image/png'
      )
      capture = job.photo_captures.create!(printer: @printer, captured_at: Time.current)
      capture.image.attach(
        io: StringIO.new('camera-bytes'),
        filename: 'camera.jpg',
        content_type: 'image/jpeg'
      )

      get printer_path(@printer)

      assert_match(/Print preview/, response.body)
      assert_select '.job-progress--timeline .progress-bar[style*="width: 50"]'
      assert_select '.h-section-label', text: 'Camera'
    end
  end

  test 'show renders print timeline for active job' do
    job = jobs(:active_xl)
    job.events.find_or_create_by!(event_type: 'started') do |event|
      event.to_status = 'printing'
      event.occurred_at = job.started_at || 30.minutes.ago
    end

    get printer_path(@printer)

    assert_select '.h-section-label', text: 'Print timeline'
    assert_select '.job-timeline__bar'
    assert_select '.job-timeline__mark-letter', text: 'S'
    assert_select '.job-timeline__legend-letter', text: 'S'
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

  test 'edit masks stored Prusa Connect token' do
    @printer.update!(prusa_connect_token: 'super-secret-connect-token')
    login_as(users(:admin))
    get edit_printer_path(@printer)

    assert_response :success
    assert_no_match(/super-secret-connect-token/, response.body)
    assert_select 'input[type=password][name=?]', 'printer[prusa_connect_token]'
    assert_match(/••••/, response.body)
  end

  test 'update keeps existing PrusaLink key when field is left blank' do
    @printer.update!(prusalink_key: 'keep-me')
    login_as(users(:admin))

    patch printer_path(@printer), params: { printer: { location: 'Lab', prusalink_key: '' } }

    assert_redirected_to printer_path(@printer)
    assert_equal 'keep-me', @printer.reload.prusalink_key
  end

  test 'update keeps existing Prusa Connect token when field is left blank' do
    @printer.update!(prusa_connect_token: 'keep-connect-token')
    login_as(users(:admin))

    patch printer_path(@printer), params: { printer: { location: 'Lab', prusa_connect_token: '' } }

    assert_redirected_to printer_path(@printer)
    assert_equal 'keep-connect-token', @printer.reload.prusa_connect_token
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

  test 'admin can add a bambu printer' do
    login_as(users(:admin))

    assert_difference -> { Printer.count } => 1 do
      post printers_path, params: {
        printer: {
          name: 'New P2S', hostname: '10.0.0.8', printer_type: 'bambu', model: 'P2S',
          bambu_serial: '00M09A000000001', bambu_access_code: 'abcd1234'
        }
      }
    end

    printer = Printer.find_by!(name: 'New P2S')

    assert_redirected_to printer_path(printer)
    assert_predicate printer, :bambu_lan?
    assert_equal 'abcd1234', printer.bambu_access_code
  end

  test 'show describes a bambu printer without revealing the access code' do
    login_as(users(:admin))
    get printer_path(printers(:bambu_p2s))

    assert_response :success
    assert_match(/Bambu LAN configured/, response.body)
    assert_match(/Sliced 3MF file/, response.body)
    assert_no_match(/abcd1234/, response.body)
  end

  test 'update keeps a bambu access code when the field is left blank' do
    login_as(users(:admin))
    patch printer_path(printers(:bambu_p2s)), params: { printer: { location: 'Annex', bambu_access_code: '' } }

    printer = printers(:bambu_p2s).reload

    assert_redirected_to printer_path(printer)
    assert_equal 'abcd1234', printer.bambu_access_code
    assert_equal 'Annex', printer.location
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

  private

  # Makes the printer's active job private and gives it a stored camera photo.
  def attach_private_print_capture
    job = jobs(:active_xl)
    job.update!(owner: users(:viewer), private: true)
    capture = @printer.photo_captures.create!(job: job, captured_at: Time.current)
    capture.image.attach(io: StringIO.new('STORED'), filename: 's.jpg', content_type: 'image/jpeg')
    job
  end
end

class PrinterControlsAccessTest < ActionDispatch::IntegrationTest
  setup do
    @printer = printers(:prusa_xl)
    @printer.update!(prusalink_key: 'k')
  end

  test 'controls are hidden from anonymous and non-admin viewers' do
    get printer_path(@printer)

    assert_select 'form[action=?]', pause_printer_path(@printer), count: 0

    login_as(users(:viewer))
    get printer_path(@printer)

    assert_select 'form[action=?]', pause_printer_path(@printer), count: 0
  end

  test 'controls are shown to admins' do
    login_as(users(:admin))
    get printer_path(@printer)

    assert_select 'form[action=?]', pause_printer_path(@printer)
    assert_select 'form[action=?]', stop_printer_path(@printer)
  end

  test 'non-admins cannot post control actions, even on the internal network' do
    post pause_printer_path(@printer)

    assert_redirected_to login_path

    login_as(users(:viewer))
    %i[pause_printer_path resume_printer_path stop_printer_path].each do |helper|
      post public_send(helper, @printer)

      assert_response :forbidden
    end
  end

  test 'admin pause calls the printer control' do
    login_as(users(:admin))
    called = false
    fake = Object.new
    fake.define_singleton_method(:pause) { called = true }
    PrinterControl.stub(:new, fake) do
      post pause_printer_path(@printer)
    end

    assert called
    assert_redirected_to printer_path(@printer)
  end

  test 'admin sees a flash when the command is not allowed' do
    login_as(users(:admin))
    fake = Object.new
    fake.define_singleton_method(:stop) { raise PrinterControl::NotAllowed, 'nope' }
    PrinterControl.stub(:new, fake) do
      post stop_printer_path(@printer)
    end

    assert_equal 'nope', flash[:alert]
  end

  test 'submit form is shown to admins only' do
    login_as(users(:admin))
    get printer_path(@printer)

    assert_select 'form[action=?]', submit_printer_path(@printer)
  end

  test 'non-admins cannot submit jobs' do
    post submit_printer_path(@printer)

    assert_redirected_to login_path

    login_as(users(:viewer))
    post submit_printer_path(@printer)

    assert_response :forbidden
  end

  test 'admin submit hands the file to the printer control' do
    login_as(users(:admin))
    received = nil
    fake = Object.new
    fake.define_singleton_method(:submit) do |file|
      received = file
      'part.gcode'
    end
    file = fixture_file_upload('sample.gcode', 'text/plain')
    PrinterControl.stub(:new, fake) do
      post submit_printer_path(@printer), params: { gcode: file }
    end

    assert_not_nil received
    assert_redirected_to printer_path(@printer)
    assert_match(/part.gcode/, flash[:notice])
  end

  test 'admin submit without a file shows an alert' do
    login_as(users(:admin))
    post submit_printer_path(@printer)

    assert_redirected_to printer_path(@printer)
    assert flash[:alert].present?
  end
end
