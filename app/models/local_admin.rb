module LocalAdmin
  module_function

  def configured?
    email.present? && password.present?
  end

  def email
    ENV['LOCAL_ADMIN_EMAIL'].to_s.strip.presence
  end

  def password
    ENV['LOCAL_ADMIN_PASSWORD'].to_s.presence
  end

  def name
    ENV.fetch('LOCAL_ADMIN_NAME', 'Local Admin').strip.presence || 'Local Admin'
  end

  def authenticate(submitted_email, submitted_password)
    return nil unless configured?
    return nil unless secure_match?(submitted_email.to_s.downcase.strip, email.downcase)
    return nil unless secure_match?(submitted_password.to_s, password)

    upsert_user
  end

  def upsert_user
    user = User.find_or_initialize_by(provider: 'local', uid: email.downcase)
    user.email = email.downcase
    user.name  = name
    user.admin = true
    user.save!
    user
  end

  def secure_match?(left, right)
    ActiveSupport::SecurityUtils.secure_compare(left, right)
  rescue ArgumentError
    false
  end
end
