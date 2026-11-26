require 'test_helper'

class FilamentTypesControllerTest < ActionDispatch::IntegrationTest
  test 'non-admins cannot manage filament types' do
    login_as(users(:viewer))

    get filament_types_path

    assert_response :forbidden
  end

  test 'admins see the list with each printer\'s allowed filaments' do
    login_as(users(:admin))

    get filament_types_path

    assert_response :success
    assert_select 'td span.fw-medium', text: 'PA-CF'
    assert_select '.printer-filaments'
  end

  test 'admins add, edit and remove filament types' do
    login_as(users(:admin))

    post filament_types_path, params: { filament_type: { name: 'TPU', aliases: 'Flex', nozzle_min_c: 200,
                                                         nozzle_max_c: 240, bed_min_c: 30, bed_max_c: 60 } }

    tpu = FilamentType.find_by!(name: 'TPU')

    assert_redirected_to filament_types_path
    assert_equal 'Flex', tpu.aliases

    patch filament_type_path(tpu), params: { filament_type: { requires_ventilation: '1', nozzle_max_c: 250 } }

    assert_predicate tpu.reload, :requires_ventilation?
    assert_equal 250, tpu.nozzle_max_c

    delete filament_type_path(tpu)

    assert_nil FilamentType.find_by(name: 'TPU')
  end

  test 'admins mark a filament type common with the star, and common types are listed first' do
    login_as(users(:admin))

    get filament_types_path

    assert_select 'tbody tr:first-child td span.fw-medium', text: 'ABS'
    assert_select "form[action='#{filament_type_path(filament_types(:pa_cf))}'] .bi-star"

    patch filament_type_path(filament_types(:pa_cf)), params: { filament_type: { common: 'true' } }

    assert_redirected_to filament_types_path
    assert_predicate filament_types(:pa_cf).reload, :common?

    patch filament_type_path(filament_types(:pla)), params: { filament_type: { common: 'false' } }

    assert_not filament_types(:pla).reload.common?
  end

  test 'invalid input re-renders the form' do
    login_as(users(:admin))

    post filament_types_path, params: { filament_type: { name: 'pla', nozzle_min_c: 230, nozzle_max_c: 190,
                                                         bed_min_c: 45, bed_max_c: 65 } }

    assert_response :unprocessable_content
    assert_select '.alert-danger', text: /already been taken/
  end
end
