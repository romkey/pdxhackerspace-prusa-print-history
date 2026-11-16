module DashboardHelper
  def dashboard_filter_href(filter_name)
    active = dashboard_active_filter_names
    filters = if active.include?(filter_name)
                active - [filter_name]
              elsif DashboardPresenter::EXCLUSIVE_STATUS_FILTERS.include?(filter_name)
                (active - DashboardPresenter::EXCLUSIVE_STATUS_FILTERS) + [filter_name]
              else
                active + [filter_name]
              end

    filters.empty? ? root_path : root_path(filter: filters)
  end

  def dashboard_filter_chip_class(filter_name)
    classes = ['filter-chip']
    classes << 'active' if dashboard_active_filter_names.include?(filter_name)
    classes.join(' ')
  end

  def dashboard_status_filter_label(filter_name)
    filter_name.humanize
  end

  def open_problem_count(printer)
    open_problem_counts.fetch(printer.id, 0)
  end

  def dashboard_service_link_class(printer)
    open_problem_count(printer).positive? ? 'text-warning' : 'text-secondary'
  end

  def dashboard_service_link_title(printer)
    count = open_problem_count(printer)
    return 'Service log' unless count.positive?

    "Service log, #{pluralize(count, 'open problem')}"
  end

  private

  def open_problem_counts
    @open_problem_counts ||= ServiceEntry.open.group(:printer_id).count
  end

  def dashboard_active_filter_names
    dashboard_active_filters.to_a
  end
end
