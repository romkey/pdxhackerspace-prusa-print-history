class JobNotificationPresenter
  def initialize(job, event:)
    @job = job
    @event = event
  end

  def subject
    case @event
    when :finished then "Print finished: #{@job.filename}"
    when :cleared  then cleared_subject
    when :attention then "Print needs attention: #{@job.filename}"
    end
  end

  def email_intro
    case @event
    when :finished then 'Your print has finished.'
    when :cleared  then cleared_intro
    when :attention then "Your print needs attention on #{@job.printer.name}."
    end
  end

  def slack_text
    [email_intro, detail_lines.join("\n")].join("\n\n")
  end

  def detail_lines
    lines = [
      "*File:* #{@job.filename}",
      "*Printer:* #{@job.printer.name}",
      "*Material:* #{material_summary}",
      "*Duration:* #{duration_label}"
    ]
    lines << "*Issue:* #{failure_label}" if @job.clear_outcome == 'failed'
    lines
  end

  def duration_label
    seconds = @job.duration_seconds
    return '—' if seconds.nil?

    ApplicationController.helpers.distance_of_time_in_words(seconds)
  end

  def material_summary
    materials = @job.tools.filter_map(&:material).uniq
    return '—' if materials.empty?

    materials.join(', ')
  end

  def failure_label
    label = Job::CLEAR_FAILURE_REASONS.fetch(@job.clear_failure_reason, @job.clear_failure_reason.to_s.humanize)
    if @job.clear_failure_reason == 'other' && @job.clear_failure_detail.present?
      "#{label}: #{@job.clear_failure_detail}"
    else
      label
    end
  end

  private

  def cleared_subject
    if @job.clear_outcome == 'failed'
      "Print failed: #{@job.filename}"
    else
      "Print ready for pickup: #{@job.filename}"
    end
  end

  def cleared_intro
    if @job.clear_outcome == 'failed'
      "Your print *#{@job.filename}* did not succeed (#{failure_label})."
    else
      "Your print *#{@job.filename}* is ready for pickup on *#{@job.printer.name}*."
    end
  end
end
