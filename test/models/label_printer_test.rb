require 'test_helper'

class LabelPrinterTest < ActiveSupport::TestCase
  test 'default returns the default printer' do
    assert_equal label_printers(:front_desk), LabelPrinter.default
  end

  test 'ensures only one default printer' do
    other = LabelPrinter.create!(
      name: 'Backup',
      cups_printer_name: 'Backup_Queue',
      default_printer: true,
      thermal_roll_width_mm: 58
    )

    assert_not label_printers(:front_desk).reload.default_printer?
    assert other.default_printer?
  end

  test 'thermal_receipt_printer? reflects roll width' do
    assert label_printers(:front_desk).thermal_receipt_printer?
    assert_not LabelPrinter.new(name: 'Office', cups_printer_name: 'HP').thermal_receipt_printer?
  end

  test 'cups_options requests portrait orientation for thermal printers' do
    assert_equal '4', label_printers(:front_desk).cups_options['orientation-requested']
    assert_equal 'none', label_printers(:front_desk).cups_options['print-scaling']
  end
end
