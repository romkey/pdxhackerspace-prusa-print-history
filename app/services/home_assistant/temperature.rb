module HomeAssistant
  module Temperature
    CELSIUS_UNITS = %w[C CELSIUS DEGC DEGREES_CELSIUS].freeze
    FAHRENHEIT_UNITS = %w[F FAHRENHEIT DEGF DEGREES_FAHRENHEIT].freeze
    KELVIN_UNITS = %w[K KELVIN DEGK DEGREES_KELVIN].freeze

    def self.to_celsius(value, unit)
      case normalize_unit(unit)
      when *FAHRENHEIT_UNITS
        fahrenheit_to_celsius(value.to_f)
      when *KELVIN_UNITS
        kelvin_to_celsius(value.to_f)
      else
        value.to_f
      end
    end

    def self.normalize_unit(unit)
      unit.to_s.strip.delete('°').delete('º').upcase.tr(' ', '_')
    end

    def self.fahrenheit_to_celsius(value)
      ((value - 32) * 5.0) / 9.0
    end

    def self.kelvin_to_celsius(value)
      value - 273.15
    end
  end
end
