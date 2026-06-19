module DashboardHelper
  def dashboard_filter_href(filter_name)
    active = dashboard_active_filter_names
    filters = if active.include?(filter_name)
                active - [filter_name]
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

  private

  def dashboard_active_filter_names
    dashboard_active_filters.to_a
  end
end
