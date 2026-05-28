require 'test_helper'

class LabelPrintersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @printer = label_printers(:front_desk)
  end

  test 'index requires admin' do
    get label_printers_path

    assert_redirected_to login_path

    login_as(users(:viewer))
    get label_printers_path

    assert_response :forbidden

    login_as(users(:admin))
    get label_printers_path

    assert_response :success
    assert_match(/Front desk label printer/, response.body)
  end

  test 'admin can create label printer' do
    login_as(users(:admin))

    assert_difference('LabelPrinter.count', 1) do
      post label_printers_path, params: {
        label_printer: {
          name: 'Shop labels',
          cups_printer_name: 'DYMO_450',
          thermal_roll_width_mm: 58,
          default_printer: false
        }
      }
    end

    assert_redirected_to label_printers_path
  end

  test 'test_print sends job to CUPS' do
    login_as(users(:admin))
    CupsService.stub(:test_print, 'test-1') do
      post test_print_label_printer_path(@printer)
    end

    assert_redirected_to label_printers_path
    assert_match(/test-1/, flash[:notice])
  end
end
