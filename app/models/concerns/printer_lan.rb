module PrinterLan
  extend ActiveSupport::Concern

  TYPES = %w[prusa bambu].freeze
  ACCESS_CODE_FORMAT = /\A[A-Za-z0-9]{8}\z/

  included do
    attribute :printer_type, :string, default: 'prusa'

    encrypts :bambu_access_code

    validates :printer_type, inclusion: { in: TYPES }
    validates :bambu_serial, presence: true, if: :bambu?
    validates :bambu_access_code, presence: true, if: :bambu_access_code_required?
    validates :bambu_access_code,
              format: { with: ACCESS_CODE_FORMAT, message: 'must be the 8 character LAN access code' },
              allow_blank: true

    before_validation :normalize_bambu_fields
  end

  def bambu?
    printer_type == 'bambu'
  end

  def bambu_lan?
    bambu? && hostname.present? && bambu_serial.present? && bambu_access_code.present?
  end

  def connection_configured?
    bambu? ? bambu_lan? : prusalink?
  end

  def connection_label
    bambu? ? 'Bambu LAN' : 'PrusaLink'
  end

  def connection_summary
    if bambu?
      bambu_lan? ? 'Bambu LAN configured' : 'Bambu LAN not configured'
    else
      prusalink? ? 'PrusaLink configured' : 'PrusaLink not configured'
    end
  end

  def camera_source_label
    return camera_url if camera?
    return 'Bambu LAN' if bambu_lan?
    return 'PrusaLink' if prusalink?

    'none'
  end

  def connection_client
    bambu? ? BambuLan::Client.new(self) : PrusaLink::Client.new(self)
  end

  private

  def bambu_access_code_required?
    bambu? && bambu_access_code.blank?
  end

  def normalize_bambu_fields
    self.bambu_serial = bambu_serial.strip.presence if bambu_serial.is_a?(String)
    self.bambu_access_code = bambu_access_code.strip if bambu_access_code.is_a?(String)
    self.printer_type = printer_type.to_s.strip.presence || 'prusa'
  end
end
