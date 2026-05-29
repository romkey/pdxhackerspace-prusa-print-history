require 'test_helper'

class EndToEndFlowTest < ActionDispatch::IntegrationTest
  setup do
    @printer = printers(:prusa_xl)
    @job     = jobs(:active_xl)
  end

  test 'anonymous viewer on the internal network can browse status pages but sees no admin affordances' do
    get root_path

    assert_response :success
    assert_select 'a', text: /Sign in/

    get printers_path

    assert_response :success

    get printer_path(@printer)

    assert_response :success
    assert_select 'a[href=?]', edit_printer_path(@printer), count: 0
    assert_select 'a[href=?]', new_printer_path,            count: 0
    assert_select '.h-section-label', text: 'Integrations', count: 0

    get jobs_path

    assert_response :success

    get job_path(@job)

    assert_response :success
    assert_select 'input[type=submit][value=?]', 'Claim', count: 0
  end

  test 'non-admin user can claim a job, see My prints, but not access settings' do
    @job.update!(owner: nil)
    login_as(users(:viewer))

    get jobs_path(owner: 'me')

    assert_response :success
    assert_select 'h1', text: /My prints/

    patch claim_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_equal users(:viewer).id, @job.reload.owner_id

    get jobs_path(owner: 'me')

    assert_response :success

    get settings_path

    assert_response :forbidden

    get new_printer_path

    assert_response :forbidden

    get '/sidekiq'

    assert_response :not_found
  end

  test 'admin user can add a printer, edit settings, and reach Sidekiq UI' do
    login_as(users(:admin))

    get settings_path

    assert_response :success
    assert_select 'h1', text: /Settings/

    patch settings_path, params: { settings: { default_ambient_sensor: 'sensor.shop_ambient_temperature_v2' } }

    assert_redirected_to settings_path
    assert_equal 'sensor.shop_ambient_temperature_v2', Setting.default_ambient_sensor

    get new_printer_path

    assert_response :success

    assert_difference -> { Printer.count } => 1 do
      post printers_path, params: { printer: { name: 'New Voron', hostname: 'voron.local', model: 'Voron 2.4' } }
    end

    created = Printer.find_by!(name: 'New Voron')
    follow_redirect!

    assert_response :success
    assert_select 'h1', text: /New Voron/

    get edit_printer_path(created)

    assert_response :success

    get '/sidekiq'

    assert_response :success
  end
end
