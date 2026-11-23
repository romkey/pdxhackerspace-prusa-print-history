require 'csv'
require 'test_helper'

class JobHistoryCsvTest < ActiveSupport::TestCase
  test 'renders a header and one row per job' do
    csv = CSV.parse(JobHistoryCsv.call([jobs(:finished)]), headers: true)

    assert_equal 1, csv.size
    assert_equal 'vase.gcode', csv.first['file']
    assert_equal '7200', csv.first['duration_seconds']
    assert_equal '42.5', csv.first['filament_grams']
  end

  test 'neutralises spreadsheet formulas in filenames' do
    job = jobs(:finished)
    job.filename = '=HYPERLINK("x")'

    csv = CSV.parse(JobHistoryCsv.call([job]), headers: true)

    assert_equal "'=HYPERLINK(\"x\")", csv.first['file']
  end
end
