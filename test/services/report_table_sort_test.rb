require 'test_helper'

class ReportTableSortTest < ActiveSupport::TestCase
  Row = Data.define(:key, :label, :week_seconds, :month_seconds, :all_seconds)
  ScoreRow = Data.define(:key, :label, :display_score)

  COLUMNS = ReportTableSort::PRINT_TIME
  SCORE_COLUMNS = { 'name' => :label, 'score' => :display_score }.freeze

  setup do
    @rows = [
      Row.new(key: 'xl', label: 'Prusa XL', week_seconds: 10, month_seconds: 30, all_seconds: 100),
      Row.new(key: 'mk4', label: 'Prusa MK4', week_seconds: 50, month_seconds: 5, all_seconds: 50),
      Row.new(key: 'mini', label: 'prusa mini', week_seconds: 50, month_seconds: 1, all_seconds: 20)
    ]
  end

  test 'sorts names case-insensitively' do
    sorted = ReportTableSort.call(@rows, columns: COLUMNS, sort: 'name', direction: 'asc')

    assert_equal ['prusa mini', 'Prusa MK4', 'Prusa XL'], sorted.map(&:label)

    descending = ReportTableSort.call(@rows, columns: COLUMNS, sort: 'name', direction: 'desc')

    assert_equal ['Prusa XL', 'Prusa MK4', 'prusa mini'], descending.map(&:label)
  end

  test 'sorts a period descending and breaks ties by name' do
    sorted = ReportTableSort.call(@rows, columns: COLUMNS, sort: 'week', direction: 'desc')

    assert_equal ['prusa mini', 'Prusa MK4', 'Prusa XL'], sorted.map(&:label)
  end

  test 'sorts a period ascending' do
    sorted = ReportTableSort.call(@rows, columns: COLUMNS, sort: 'all', direction: 'asc')

    assert_equal ['prusa mini', 'Prusa MK4', 'Prusa XL'], sorted.map(&:label)
  end

  test 'unknown sort falls back to name ascending' do
    column, direction = ReportTableSort.normalize('nope', 'sideways', COLUMNS)

    assert_equal %w[name asc], [column, direction]
  end

  test 'missing scores stay after real scores in both directions' do
    rows = [
      ScoreRow.new(key: 'a', label: 'Alpha', display_score: nil),
      ScoreRow.new(key: 'd', label: 'Delta', display_score: nil),
      ScoreRow.new(key: 'b', label: 'Beta', display_score: 0),
      ScoreRow.new(key: 'c', label: 'Gamma', display_score: 80)
    ]

    descending = ReportTableSort.call(rows, columns: SCORE_COLUMNS, sort: 'score', direction: 'desc')
    ascending = ReportTableSort.call(rows, columns: SCORE_COLUMNS, sort: 'score', direction: 'asc')

    assert_equal %w[Gamma Beta Alpha Delta], descending.map(&:label)
    assert_equal %w[Beta Gamma Alpha Delta], ascending.map(&:label)
  end

  test 'a period with no direction defaults to descending' do
    column, direction = ReportTableSort.normalize('month', nil, COLUMNS)

    assert_equal %w[month desc], [column, direction]
  end
end
