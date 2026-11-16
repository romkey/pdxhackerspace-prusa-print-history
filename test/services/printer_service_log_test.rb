require 'test_helper'

class PrinterServiceLogTest < ActiveSupport::TestCase
  setup do
    @printer = printers(:prusa_mini)
    @user = users(:viewer)
  end

  test 'a problem report can take a signed-in printer out of service' do
    entry = PrinterServiceLog.report_problem!(
      printer: @printer, user: @user, summary: 'Grinding', details: 'On the Y axis', take_out_of_service: true
    )

    assert entry.open_problem?
    assert_equal @user, entry.user
    assert_equal 'On the Y axis', entry.details
    assert @printer.reload.out_of_service?
    assert @printer.service_entries.exists?(kind: 'out_of_service', summary: 'Grinding')
  end

  test 'an anonymous report is kept and cannot take a printer out of service' do
    entry = PrinterServiceLog.report_problem!(
      printer: @printer, user: nil, summary: 'Smell', take_out_of_service: true
    )

    assert_nil entry.user
    assert_not @printer.reload.out_of_service?
    assert_not @printer.service_entries.exists?(kind: 'out_of_service')
  end

  test 'a repair resolves the selected problems and can return the printer to service' do
    problem = PrinterServiceLog.report_problem!(
      printer: @printer, user: @user, summary: 'Skipped layers', take_out_of_service: true
    )

    repair = PrinterServiceLog.log_repair!(
      printer: @printer, user: @user, summary: 'Replaced the nozzle',
      resolves: [problem.id], return_to_service: true
    )

    assert_equal repair, problem.reload.resolving_repair
    assert_equal @user, problem.resolved_by
    assert problem.resolved_at.present?
    assert_not @printer.reload.out_of_service?
    assert @printer.service_entries.exists?(kind: 'back_in_service')
  end

  test 'a repair does not resolve another printer problem and is rolled back' do
    other = PrinterServiceLog.report_problem!(printer: printers(:prusa_xl), user: @user, summary: 'Other')

    assert_no_difference -> { ServiceEntry.repairs.count } do
      error = assert_raises(PrinterServiceLog::Error) do
        PrinterServiceLog.log_repair!(
          printer: @printer, user: @user, summary: 'Tightened a belt', resolves: [other.id]
        )
      end
      assert_match(/open problem/, error.message)
    end
    assert_nil other.reload.resolved_at
  end

  test 'taking a printer out twice and returning it early are refused' do
    PrinterServiceLog.take_out_of_service!(printer: @printer, user: @user, reason: 'Board')

    assert_raises(PrinterServiceLog::Error) do
      PrinterServiceLog.take_out_of_service!(printer: @printer, user: @user, reason: 'Again')
    end

    PrinterServiceLog.return_to_service!(printer: @printer, user: @user, note: 'Back in service')

    assert_raises(PrinterServiceLog::Error) do
      PrinterServiceLog.return_to_service!(printer: @printer, user: @user, note: 'Again')
    end
    assert_not @printer.reload.out_of_service?
  end

  test 'resolving closes an open problem without a repair' do
    problem = PrinterServiceLog.report_problem!(printer: @printer, user: @user, summary: 'User error')

    PrinterServiceLog.resolve_problem!(problem, user: @user)

    assert problem.reload.resolved_problem?
    assert_nil problem.resolving_repair
    assert_raises(PrinterServiceLog::Error) { PrinterServiceLog.resolve_problem!(problem, user: @user) }
  end

  test 'a repair requires a signed-in user and a real time' do
    assert_raises(PrinterServiceLog::Error) do
      PrinterServiceLog.log_repair!(printer: @printer, user: nil, summary: 'Nope')
    end

    assert_no_difference -> { ServiceEntry.count } do
      assert_raises(PrinterServiceLog::Error) do
        PrinterServiceLog.log_repair!(
          printer: @printer, user: @user, summary: 'Nope', occurred_at: 'not a time'
        )
      end
    end
  end
end
