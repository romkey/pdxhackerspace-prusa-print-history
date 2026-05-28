class LabelPrinter < ApplicationRecord
  HEALTH_STATUSES = %w[unknown healthy unhealthy].freeze
  THERMAL_WIDTHS = [58, 72, 80, 88].freeze

  before_validation :normalize_cups_printer_server

  validates :name, presence: true, uniqueness: true
  validates :cups_printer_name, presence: true, uniqueness: { scope: :cups_printer_server }
  validates :health_status, inclusion: { in: HEALTH_STATUSES }
  validates :thermal_roll_width_mm,
            allow_nil: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 48, less_than_or_equal_to: 112 }

  scope :ordered, -> { order(:position, :name) }
  scope :default_printer, -> { where(default_printer: true) }

  before_save :ensure_single_default

  def self.default
    default_printer.first || ordered.first
  end

  def cups_destination
    return cups_printer_name if cups_printer_server.blank?

    "#{cups_printer_server}/#{cups_printer_name}"
  end

  def thermal_receipt_printer?
    thermal_roll_width_mm.present?
  end

  def receipt_paper_summary
    thermal_receipt_printer? ? "#{thermal_roll_width_mm} mm thermal" : 'Letter / A4'
  end

  def cups_options
    return {} unless thermal_receipt_printer?

    CupsService::THERMAL_PDF_OPTIONS
  end

  private

  def normalize_cups_printer_server
    self.cups_printer_server = cups_printer_server.to_s.strip.presence
  end

  def ensure_single_default
    return unless default_printer? && default_printer_changed?

    LabelPrinter.where.not(id: id).update_all(default_printer: false) # rubocop:disable Rails/SkipsModelValidations
  end
end
