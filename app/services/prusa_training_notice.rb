class PrusaTrainingNotice
  PRUSA = 'Prusa'.freeze

  def self.for_auth(auth, user:)
    new(auth, user: user).message
  end

  def initialize(auth, user:)
    @auth = auth
    @user = user
  end

  def message
    return if @user.admin?
    return unless @auth.provider == 'authentik'
    return if User.trained_on?(@auth, PRUSA)

    parts = [
      Setting.prusa_untrained_message,
      Setting.prusa_trained_account_message
    ].filter_map(&:presence)

    parts.join("\n\n").presence
  end
end
