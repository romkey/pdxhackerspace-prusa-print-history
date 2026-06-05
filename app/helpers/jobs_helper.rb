module JobsHelper
  def job_timeline_start_label(timeline)
    return '—' unless timeline.start_at

    "Start · #{l(timeline.start_at, format: :short)}"
  end

  def job_timeline_end_label(timeline)
    return '—' unless timeline.end_at

    prefix = timeline.active? ? 'Now' : 'End'
    "#{prefix} · #{l(timeline.end_at, format: :short)}"
  end
end
