module JobsHelper
  JOBS_FILTER_PARAMS = %i[status printer_id owner started_after started_before].freeze

  def jobs_active_statuses
    Array(params[:status]).map(&:to_s).select { |s| Job::STATUSES.include?(s) }
  end

  def jobs_toggle_status_path(status_value)
    active = jobs_active_statuses
    new_statuses = active.include?(status_value) ? active - [status_value] : active + [status_value]
    jobs_path(jobs_filter_params.merge(status: new_statuses.presence))
  end

  def jobs_toggle_printer_path(printer_id)
    current = params[:printer_id].to_s
    new_id = current == printer_id.to_s ? nil : printer_id
    jobs_path(jobs_filter_params.merge(printer_id: new_id))
  end

  def jobs_toggle_owner_path
    new_owner = params[:owner] == 'me' ? nil : 'me'
    jobs_path(jobs_filter_params.merge(owner: new_owner))
  end

  def jobs_filter_chip_class(active)
    active ? 'filter-chip active' : 'filter-chip'
  end

  def jobs_active_filter_count
    count = 0
    count += jobs_active_statuses.size
    count += 1 if params[:printer_id].present?
    count += 1 if params[:owner] == 'me'
    count += 1 if params[:started_after].present?
    count += 1 if params[:started_before].present?
    count
  end

  def jobs_filter_params
    params.permit(*JOBS_FILTER_PARAMS).to_h.symbolize_keys.reject { |_, v| v.blank? }
  end

  def job_timeline_start_label(timeline)
    return '—' unless timeline.start_at

    "Start · #{l(timeline.start_at, format: :short)}"
  end

  def job_timeline_end_label(timeline)
    return '—' unless timeline.end_at

    if timeline.estimated_finish?
      "Est. finish · #{l(timeline.end_at, format: :short)}"
    elsif timeline.active?
      "Now · #{l(timeline.now, format: :short)}"
    else
      "End · #{l(timeline.end_at, format: :short)}"
    end
  end

  def job_progress_timeline?(job)
    job.active? &&
      job.started_at.present? &&
      job.estimated_finish_at.present? &&
      job.estimated_finish_at > job.started_at
  end

  PRIVATE_FILENAME_LABEL = 'Private print'.freeze
  PRIVATE_OWNER_LABEL = 'Private'.freeze

  # Single choke point for progress: the _progress partial and every caller of it
  # already ask this first, so private prints never render a progress bar.
  def job_progress_visible?(job)
    return false unless job_details_visible?(job)

    job_progress_timeline?(job) || job.progress_percent.present?
  end

  def job_filename_label(job)
    job_details_visible?(job) ? job.filename : PRIVATE_FILENAME_LABEL
  end

  def job_owner_label(job)
    return PRIVATE_OWNER_LABEL unless job_details_visible?(job)

    job.owner&.display_name || '—'
  end

  def job_progress_bar_percent(job)
    if job_progress_timeline?(job)
      total = job.estimated_finish_at - job.started_at
      elapsed = Time.current - job.started_at
      (elapsed / total * 100).clamp(0, 100).round(2)
    elsif job.progress_percent.present?
      job.progress_percent.to_f.clamp(0, 100).round(2)
    end
  end

  def job_telemetry_section_label(job)
    job.active? ? 'Current telemetry' : 'Last telemetry'
  end

  def job_show_claim_button?(job)
    logged_in? && job.owner.nil?
  end

  def job_show_clear_button?(job)
    can_clear_prints? && job.clearable?
  end

  def dashboard_action_job(card)
    card.current_job || (card.idle? ? card.last_job : nil)
  end
end
