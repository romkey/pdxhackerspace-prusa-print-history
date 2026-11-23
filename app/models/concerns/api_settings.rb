# API, token and login-link policy settings, mixed into Setting with `extend` so they read
# as Setting.api_enabled?, Setting.api_member_token_default_days, and so on.
#
# Numbers (days, minutes) distinguish "never set" (use the default) from "set blank" (no
# limit / no expiry / no grace period). Only positive whole numbers are stored; anything
# else is stored blank.
module ApiSettings
  BOOLEAN_DEFAULTS = {
    api_enabled: false,
    api_members_can_create_tokens: true,
    api_require_internal_network: false,
    members_can_undo_clear: true,
    login_links_enabled: true,
    login_links_allow_admins: false
  }.freeze

  NUMBER_DEFAULTS = {
    api_member_token_default_days: 365,
    api_member_token_max_days: nil,
    api_admin_token_default_days: 90,
    api_admin_token_max_days: nil,
    api_token_renew_grace_days: 30,
    api_token_max_login_age_days: nil,
    login_link_ttl_minutes: 60,
    login_link_qr_ttl_minutes: 5,
    api_kiosk_session_minutes: 2
  }.freeze

  DEFAULT_MEMBER_MAX_ACCESS_LEVEL = 'read_write_delete'.freeze

  KEYS = (BOOLEAN_DEFAULTS.keys + NUMBER_DEFAULTS.keys + %i[api_member_max_access_level]).map(&:to_s).freeze

  BOOLEAN_DEFAULTS.each do |key, default|
    define_method(:"#{key}?") { boolean_setting(key, default) }
    define_method(:"#{key}=") { |value| set(key, ActiveModel::Type::Boolean.new.cast(value) ? 'true' : 'false') }
  end

  NUMBER_DEFAULTS.each do |key, default|
    define_method(key) { number_setting(key, default) }
    define_method(:"#{key}=") { |value| set(key, normalize_number(value)) }
  end

  # The highest access level a member's token can use, whatever level the token was issued
  # with. Admin tokens are never capped.
  def api_member_max_access_level
    value = fetch(:api_member_max_access_level)
    ApiToken::ACCESS_LEVELS.include?(value) ? value : DEFAULT_MEMBER_MAX_ACCESS_LEVEL
  end

  def api_member_max_access_level=(value)
    value = value.to_s
    set(:api_member_max_access_level, ApiToken::ACCESS_LEVELS.include?(value) ? value : DEFAULT_MEMBER_MAX_ACCESS_LEVEL)
  end

  private

  def boolean_setting(key, default)
    value = fetch(key)
    return default if value.nil?

    value == 'true'
  end

  def number_setting(key, default)
    record = find_by(key: key.to_s)
    return default if record.nil?

    number = record.value.to_i
    number.positive? ? number : nil
  end

  def normalize_number(value)
    number = Integer(value.to_s.strip, 10, exception: false)
    number&.positive? ? number.to_s : ''
  end
end
