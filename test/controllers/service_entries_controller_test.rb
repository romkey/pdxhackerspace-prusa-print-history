require 'test_helper'

class ServiceEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @printer = printers(:prusa_xl)
    @user = users(:viewer)
  end

  test 'visitors from outside the shop network are sent to sign in' do
    get service_log_path, headers: external_request_headers

    assert_redirected_to login_path
  end

  test 'shop network visitors can read the log and report a problem' do
    get service_log_path

    assert_response :success
    assert_select 'h1', text: /Service log/
    assert_select 'a.nav-link.active', text: 'Service log'
    assert_select 'a.filter-chip', text: 'Problems'

    assert_difference -> { ServiceEntry.problems.count }, 1 do
      post problem_reports_path, params: problem_params(summary: 'Clicking extruder')
    end

    assert_redirected_to service_printer_path(@printer)
    follow_redirect!

    assert_match 'Clicking extruder', response.body
    assert_match 'Shop visitor', response.body
    assert_not @printer.reload.out_of_service?
  end

  test 'a shop network visitor cannot log a repair or take a printer out of service' do
    assert_no_difference -> { ServiceEntry.repairs.count } do
      post repair_entries_path, params: repair_params
    end
    assert_redirected_to login_path

    assert_no_difference -> { ServiceEntry.count } do
      post out_of_service_printer_path(@printer), params: { service_entry: { summary: 'Board' } }
    end
    assert_redirected_to login_path
  end

  test 'a signed-in user can report a problem and take the printer out of service' do
    login_as(@user)

    post problem_reports_path, params: problem_params(summary: 'Belt slip', take_out_of_service: '1')

    assert_redirected_to service_printer_path(@printer)
    assert @printer.reload.out_of_service?
    assert_equal 'Belt slip', @printer.service_entries.find_by(kind: 'out_of_service').summary
  end

  test 'a signed-in user can log a repair that resolves a problem and returns the printer' do
    problem = PrinterServiceLog.report_problem!(
      printer: @printer, user: @user, summary: 'Under extrusion', take_out_of_service: true
    )
    login_as(@user)

    post repair_entries_path, params: repair_params(
      summary: 'Replaced the nozzle', return_to_service: '1', resolves: [problem.id.to_s]
    )

    assert_redirected_to service_printer_path(@printer)
    assert problem.reload.resolved_problem?
    assert_not @printer.reload.out_of_service?
  end

  test 'a signed-in user can resolve a problem and return a printer from its log' do
    problem = PrinterServiceLog.report_problem!(printer: @printer, user: @user, summary: 'False alarm')
    PrinterServiceLog.take_out_of_service!(printer: @printer, user: @user, reason: 'Checking')
    login_as(@user)

    patch resolve_problem_path(problem)
    delete return_to_service_printer_path(@printer)

    assert problem.reload.resolved_problem?
    assert_not @printer.reload.out_of_service?
  end

  test 'filter chips limit the log and clear back to the full list' do
    PrinterServiceLog.report_problem!(printer: @printer, user: @user, summary: 'Extruder clicking')
    PrinterServiceLog.log_repair!(printer: @printer, user: @user, summary: 'Nozzle replaced')

    get service_log_path, params: { kind: 'repair' }

    assert_response :success
    assert_match 'Nozzle replaced', response.body
    assert_no_match(/Extruder clicking/, response.body)
    assert_select 'a.filter-chip.active[href=?]', service_log_path

    get service_printer_path(@printer), params: { state: 'open' }

    assert_match 'Extruder clicking', response.body
    assert_no_match(/Nozzle replaced/, response.body)
  end

  test 'a failed repair keeps the summary, details, and time' do
    problem = PrinterServiceLog.report_problem!(printer: @printer, user: @user, summary: 'Under extrusion')
    PrinterServiceLog.resolve_problem!(problem, user: @user)
    login_as(@user)

    post repair_entries_path, params: repair_params(
      summary: 'Swapped the hotend', details: 'New heater block', occurred_at: '2026-11-01T09:30',
      resolves: [problem.id.to_s]
    )

    assert_response :unprocessable_content
    assert_select 'input[name="service_entry[summary]"][value=?]', 'Swapped the hotend'
    assert_select 'textarea[name="service_entry[details]"]', text: 'New heater block'
    assert_select 'input[name="service_entry[occurred_at]"][value=?]', '2026-11-01T09:30'
    assert_match 'Choose open problem reports for this printer.', response.body
  end

  test 'an unparseable repair time stays in the form' do
    login_as(@user)

    post repair_entries_path, params: repair_params(
      summary: 'Swapped the hotend', details: 'New heater block', occurred_at: 'not-a-time'
    )

    assert_response :unprocessable_content
    assert_select 'input[name="service_entry[summary]"][value=?]', 'Swapped the hotend'
    assert_select 'textarea[name="service_entry[details]"]', text: 'New heater block'
    assert_select 'input[name="service_entry[occurred_at]"][value=?]', 'not-a-time'
    assert_match 'Enter a valid date and time.', response.body
  end

  test 'a blank problem report is rejected' do
    post problem_reports_path, params: problem_params(summary: '')

    assert_response :unprocessable_content
  end

  private

  def problem_params(summary:, take_out_of_service: nil)
    entry = { printer_id: @printer.id, summary:, details: 'Heard it from across the shop' }
    entry[:take_out_of_service] = take_out_of_service if take_out_of_service
    { service_entry: entry }
  end

  def repair_params(summary: 'Replaced the nozzle', details: '', occurred_at: Time.current.iso8601,
                    return_to_service: '0', resolves: [''])
    {
      service_entry: {
        printer_id: @printer.id, summary:, details:, occurred_at:, return_to_service:, resolves:
      }
    }
  end
end
