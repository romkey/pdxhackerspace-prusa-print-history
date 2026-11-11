module BambuLan
  module Host
    def self.for(printer)
      value = printer.hostname.to_s.strip
      value = value.sub(%r{\A[a-z][a-z0-9+.-]*://}i, '')
      value = value.split('/').first.to_s
      value.sub(/:\d+\z/, '')
    end
  end
end
