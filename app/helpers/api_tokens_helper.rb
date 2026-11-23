module ApiTokensHelper
  STATE_DOT_CLASSES = {
    'active' => 'status-success',
    'paused' => 'status-warning',
    'expired' => 'status-muted',
    'revoked' => 'status-muted'
  }.freeze

  def api_token_state_dot(token)
    tag.span(class: "status-dot #{STATE_DOT_CLASSES.fetch(token.state, 'status-muted')}",
             title: token.state.capitalize)
  end

  # Active tokens are the common case, so only the exceptions get a label.
  def api_token_state_badge(token)
    case token.state
    when 'paused' then tag.span('Paused', class: 'badge text-bg-warning-subtle')
    when 'expired' then tag.span('Expired', class: 'badge text-bg-secondary-subtle')
    when 'revoked' then tag.span('Revoked', class: 'badge text-bg-secondary-subtle')
    end
  end

  def api_token_expiry_label(token)
    return tag.span('Never', class: 'text-secondary') if token.expires_at.nil?

    full = l(token.expires_at.in_time_zone, format: :long)
    if token.expired?
      tag.span("#{time_ago_in_words(token.expires_at)} ago", title: full, class: 'text-secondary')
    else
      label = "in #{distance_of_time_in_words(Time.current, token.expires_at)}"
      tag.span(label, title: full, class: api_token_expiry_class(token))
    end
  end

  def api_token_last_used_label(token)
    return tag.span('Never', class: 'text-secondary') if token.last_used_at.nil?

    tag.span(relative_timestamp(token.last_used_at), title: l(token.last_used_at.in_time_zone, format: :long))
  end

  def api_token_level_options(owner)
    ApiTokenRules.levels_for(owner).map { |level| [ApiToken::ACCESS_LEVEL_LABELS[level], level] }
  end

  def api_token_lifetime_hint(owner)
    max = ApiTokenRules.max_days_for(owner)
    return 'Leave blank for a token that never expires.' if max.nil?

    "Tokens for #{owner.admin? ? 'admins' : 'members'} must expire within #{pluralize(max, 'day')}."
  end

  private

  def api_token_expiry_class(token)
    token.expires_at < 7.days.from_now ? 'text-warning fw-medium' : ''
  end
end
