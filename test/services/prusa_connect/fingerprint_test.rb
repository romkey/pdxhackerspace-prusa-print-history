require 'test_helper'

module PrusaConnect
  class FingerprintTest < ActiveSupport::TestCase
    test 'generate returns a 32-character alphanumeric string' do
      fingerprint = Fingerprint.generate

      assert_equal 32, fingerprint.length
      assert_match(/\A[A-Za-z0-9]+\z/, fingerprint)
    end

    test 'generate returns unique values' do
      fingerprints = Array.new(10) { Fingerprint.generate }

      assert_equal fingerprints.uniq.length, fingerprints.length
    end
  end
end
