module SlackConfig
  module_function

  def configured?
    api_token.present?
  end

  def api_token
    ENV['SLACK_API_TOKEN'].presence
  end
end
