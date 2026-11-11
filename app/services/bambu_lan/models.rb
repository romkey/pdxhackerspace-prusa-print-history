module BambuLan
  # Which LAN camera transport a model speaks, and whether its chamber
  # temperature is a real sensor. P2S and the X/H series use RTSPS on port
  # 322; P1 and A1 still use the JPEG stream on port 6000.
  module Models
    NAMES = ['X1', 'X1C', 'X1E', 'P1P', 'P1S', 'P2S', 'A1', 'A1 mini', 'H2D', 'H2S', 'H2C'].freeze

    CAMERAS = [
      [/P2S/, :rtsps],
      [/X1E/, :rtsps],
      [/X1C/, :rtsps],
      [/X1/, :rtsps],
      [/H2D/, :rtsps],
      [/H2S/, :rtsps],
      [/H2C/, :rtsps],
      [/A1MINI/, :jpeg],
      [/P1P/, :jpeg],
      [/P1S/, :jpeg],
      [/A1/, :jpeg]
    ].freeze

    def self.camera(model)
      key = normalize(model)
      found = CAMERAS.find { |pattern, _transport| key.match?(pattern) }
      found ? found.last : :auto
    end

    def self.chamber?(model)
      normalize(model).match?(/X1|H2|P1S|P2S/)
    end

    def self.normalize(model)
      model.to_s.upcase.gsub(/[^A-Z0-9]/, '')
    end
  end
end
