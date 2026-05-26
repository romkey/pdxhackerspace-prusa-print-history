module AdminEmails
  module_function

  def list
    @list ||= ENV.fetch('ADMIN_EMAILS', '')
                 .split(/[\s,]+/)
                 .map { |entry| entry.downcase.strip }
                 .reject(&:empty?)
                 .freeze
  end

  def include?(email)
    return false if email.blank?

    list.include?(email.to_s.downcase.strip)
  end

  def reset!
    @list = nil
  end
end
