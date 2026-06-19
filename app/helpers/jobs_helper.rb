module JobsHelper
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

  def job_progress_visible?(job)
    job_progress_timeline?(job) || job.progress_percent.present?
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
