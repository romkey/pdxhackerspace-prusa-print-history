module PrusaConnect
  module Fingerprint
    CHARSET = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a
    LENGTH = 32

    module_function

    def generate
      Array.new(LENGTH) { CHARSET.sample(random: SecureRandom) }.join
    end
  end
end
