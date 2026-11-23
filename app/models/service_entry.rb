class ServiceEntry < ApplicationRecord
  KINDS = %w[problem repair out_of_service back_in_service].freeze

  belongs_to :printer, inverse_of: :service_entries
  belongs_to :user, optional: true
  belongs_to :resolved_by, class_name: 'User', optional: true
  belongs_to :resolving_repair, class_name: 'ServiceEntry', optional: true
  has_many :resolved_problems, class_name: 'ServiceEntry', foreign_key: :resolving_repair_id,
                               dependent: :nullify, inverse_of: :resolving_repair

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :summary, presence: true, length: { maximum: 200 }
  validates :occurred_at, presence: true
  validate :resolution_fits_kind
  validate :resolving_repair_is_repair
  validate :only_faults_skip_reliability

  scope :problems, -> { where(kind: 'problem') }
  scope :repairs, -> { where(kind: 'repair') }
  scope :open, -> { problems.where(resolved_at: nil) }
  scope :resolved, -> { problems.where.not(resolved_at: nil) }
  scope :recent, -> { order(occurred_at: :desc, id: :desc) }

  def problem? = kind == 'problem'
  def repair? = kind == 'repair'
  def open_problem? = problem? && resolved_at.nil?
  def resolved_problem? = problem? && resolved_at.present?
  def reliability_relevant? = (problem? || repair?) && !automatic?
  def excluded_from_reliability? = reliability_relevant? && !counts_toward_reliability?

  private

  def resolution_fits_kind
    return if problem?
    return if resolved_at.blank? && resolved_by_id.blank? && resolving_repair_id.blank?

    errors.add(:base, 'Only problem reports can be resolved')
  end

  def only_faults_skip_reliability
    return if counts_toward_reliability? || reliability_relevant?

    errors.add(:counts_toward_reliability, 'applies only to problems and repairs')
  end

  def resolving_repair_is_repair
    return if resolving_repair_id.blank?
    return if resolving_repair&.repair?

    errors.add(:resolving_repair, 'must be a repair')
  end
end
