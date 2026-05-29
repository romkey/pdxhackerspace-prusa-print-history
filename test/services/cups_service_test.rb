require 'test_helper'

class CupsServiceTest < ActiveSupport::TestCase
  SuccessStatus = Struct.new(:success?, :exitstatus)

  test 'available_printers returns empty when lpstat is missing' do
    Open3.stub(:capture3, ->(*_args) { raise Errno::ENOENT }) do
      assert_equal [], CupsService.available_printers
    end
  end

  test 'print_data writes temp file and calls lp' do
    captured_args = nil
    Open3.stub(:capture3, lambda { |*args|
      captured_args = args
      ['request id is DYMO-42 (1 file(s))', '', SuccessStatus.new(true, 0)]
    }) do
      job_id = CupsService.print_data('pdf-bytes', 'DYMO_LabelWriter', filename: 'label.pdf')

      assert_equal 'DYMO-42', job_id
      assert_equal 'lp', captured_args.first
      assert_includes captured_args, '-d'
      assert_includes captured_args, 'DYMO_LabelWriter'
    end
  end

  test 'print_data passes remote server flag' do
    captured_args = nil
    Open3.stub(:capture3, lambda { |*args|
      captured_args = args
      ['request id is remote-1 (1 file(s))', '', SuccessStatus.new(true, 0)]
    }) do
      CupsService.print_data('pdf-bytes', 'Queue', cups_printer_server: 'print.example.org')

      assert_includes captured_args, '-h'
      assert_includes captured_args, 'print.example.org'
    end
  end

  test 'print_cut sends esc pos cut command as raw job' do
    captured_args = nil
    Open3.stub(:capture3, lambda { |*args|
      captured_args = args
      ['request id is cut-9 (1 file(s))', '', SuccessStatus.new(true, 0)]
    }) do
      job_id = CupsService.print_cut('ReceiptPrinter', cups_printer_server: 'print.example.org')

      assert_equal 'cut-9', job_id
      assert_equal 'lp', captured_args.first
      assert_includes captured_args, '-o'
      assert_includes captured_args, 'raw'
      assert_includes captured_args, '-h'
      assert_includes captured_args, 'print.example.org'
    end
  end

  test 'printer_health detects disabled printer' do
    Open3.stub(:capture3, lambda { |*_args|
      ['printer DYMO is disabled.', '', SuccessStatus.new(true, 0)]
    }) do
      result = CupsService.printer_health('DYMO')

      assert_not result.ok
      assert_match(/disabled/i, result.message)
    end
  end
end
