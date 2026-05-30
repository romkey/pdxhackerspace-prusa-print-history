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
end
