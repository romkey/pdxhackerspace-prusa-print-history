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
