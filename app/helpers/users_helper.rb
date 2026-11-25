module UsersHelper
  def user_claimed_jobs(user)
    user.owned_jobs.sort_by { |job| [job.started_at || job.created_at, job.id] }.reverse
  end

  def user_last_login_label(user)
    return '—' if user.last_login_at.blank?

    "#{time_ago_in_words(user.last_login_at)} ago"
  end

  def user_last_login_title(user)
    return nil if user.last_login_at.blank?

    l(user.last_login_at, format: :precise)
  end

  def user_notification_label(enabled)
    enabled ? 'On' : 'Off'
  end

  def user_admin_label(user)
    if user.admin?
      tag.span('Yes', class: 'badge text-bg-secondary-subtle')
    else
      tag.span('No', class: 'text-secondary')
    end
  end

  def user_training_label(user)
    return tag.span(user.trained_on.join(', '), class: 'fw-medium') if user.trained_on.any?
    return tag.span('—', class: 'text-secondary') if user.trained_on_prusa.nil?

    tag.span('None', class: 'text-secondary')
  end

  def user_access_title(user)
    return nil if user.last_login_at.blank?

    "From Authentik at last sign-in (#{l(user.last_login_at, format: :precise)})"
  end
end
