# Audit trail for API tokens: lifecycle changes made in the web UI, and every API call that
# changes something. Read requests are not recorded; ApiToken#last_used_at covers them.
class ApiTokenEvent < ApplicationRecord
  belongs_to :api_token, optional: true
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, presence: true
  validates :occurred_at, presence: true

  before_validation { self.occurred_at ||= Time.current }

  scope :recent, -> { order(occurred_at: :desc) }

  # `attributes` may carry :ip and :detail.
  def self.record!(action:, token: nil, actor: nil, subject: nil, **attributes)
    create!(api_token: token, actor:, subject:, action:, **attributes.slice(:ip, :detail))
  end

  def label
    action.to_s.tr('_.', '  ').strip.capitalize
  end
end
