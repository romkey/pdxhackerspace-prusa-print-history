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

  def user_prusa_training_label(user)
    case user.trained_on_prusa
    when true
      tag.span('Yes', class: 'fw-medium')
    when false
      tag.span('No', class: 'text-secondary')
    else
      tag.span('—', class: 'text-secondary')
    end
  end

  def user_access_title(user)
    return nil if user.last_login_at.blank?

    "From Authentik at last sign-in (#{l(user.last_login_at, format: :precise)})"
  end
end
