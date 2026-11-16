module ReportsHelper
  def reports_nav_class(report_type)
    active = controller_name == 'reports' && action_name == report_type.to_s
    "nav-link #{'active' if active}"
  end

  def print_time_report_path(report_type)
    case report_type
    when :printers then printers_reports_path
    when :users then users_reports_path
    when :filament then filament_reports_path
    else
      reports_path
    end
  end

  def print_time_report_summary(rows)
    total_seconds = rows.sum(&:all_seconds)
    active_count = rows.count { |row| row.all_seconds.positive? }

    safe_join(
      [
        tag.span(active_count, class: 'text-body'),
        ' with print time · ',
        tag.span(format_print_duration(total_seconds), class: total_seconds.positive? ? 'text-body' : 'text-secondary'),
        ' total'
      ]
    )
  end

  def attention_events_report_summary(rows)
    total_count = rows.sum(&:all_count)
    active_count = rows.count { |row| row.all_count.positive? }

    safe_join(
      [
        tag.span(active_count, class: 'text-body'),
        ' with attention events · ',
        tag.span(total_count, class: total_count.positive? ? 'text-body fw-medium' : 'text-secondary'),
        ' total'
      ]
    )
  end

  def report_column_heading(label, column, sort_column:, sort_direction:, numeric: false)
    return label if sort_column.blank?

    link_to(
      report_sort_path(column, sort_column:, sort_direction:, numeric:),
      class: report_sort_link_class(column, sort_column:, numeric:)
    ) do
      safe_join([label, report_sort_icon(column, sort_column:, sort_direction:)].compact)
    end
  end

  def report_header_attributes(column, sort_column:, sort_direction:)
    return if sort_column.blank?

    state = sort_column == column ? report_aria_sort_state(sort_direction) : 'none'
    tag.attributes(aria: { sort: state })
  end

  def format_report_count_cell(count)
    if count.to_i <= 0
      tag.span('—', class: 'text-secondary')
    else
      count.to_i
    end
  end

  private

  def report_sort_path(column, sort_column:, sort_direction:, numeric:)
    url_for(sort: column, direction: next_report_sort_direction(column, sort_column:, sort_direction:, numeric:))
  end

  def next_report_sort_direction(column, sort_column:, sort_direction:, numeric:)
    return opposite_report_sort_direction(sort_direction) if sort_column == column

    numeric ? 'desc' : 'asc'
  end

  def opposite_report_sort_direction(sort_direction)
    sort_direction == 'asc' ? 'desc' : 'asc'
  end

  def report_sort_link_class(column, sort_column:, numeric:)
    classes = %w[text-decoration-none text-nowrap align-items-center gap-1]
    classes << (numeric ? 'd-flex w-100 justify-content-end' : 'd-inline-flex')
    classes << (sort_column == column ? 'link-body-emphasis' : 'link-secondary')
    classes.join(' ')
  end

  def report_sort_icon(column, sort_column:, sort_direction:)
    return if sort_column != column

    icon = sort_direction == 'asc' ? 'bi-caret-up-fill' : 'bi-caret-down-fill'
    tag.i(class: "bi #{icon}", aria: { hidden: true })
  end

  def report_aria_sort_state(sort_direction)
    sort_direction == 'asc' ? 'ascending' : 'descending'
  end
end
