require 'test_helper'

module PrusaConnect
  class ClientTest < ActiveSupport::TestCase
    setup do
      @printer = printers(:prusa_xl)
      @printer.update!(
        prusa_connect_token: 'camera-token-12345678',
        prusa_connect_fingerprint: 'fingerprint-abc'
      )
      @client = Client.new(@printer, snapshot_url: 'https://webcam.connect.prusa3d.com/c/snapshot')
    end

    test 'upload_snapshot sends token and fingerprint headers' do
      stub_http(StubResponse.ok) do |captured|
        assert @client.upload_snapshot('JPEG-BYTES', content_type: 'image/jpeg')
        assert_equal 'PUT', captured[:request].method
        assert_equal '/c/snapshot', captured[:request].path
        assert_equal 'camera-token-12345678', captured[:request]['Token']
        assert_equal 'fingerprint-abc', captured[:request]['Fingerprint']
        assert_equal 'image/jpeg', captured[:request]['Content-Type']
        assert_equal 'JPEG-BYTES', captured[:request].body
      end
    end

    test 'upload_snapshot raises RateLimited on 429' do
      stub_http(StubResponse.new(Net::HTTPTooManyRequests, '429')) do
        assert_raises(RateLimited) do
          @client.upload_snapshot('JPEG-BYTES')
        end
      end
    end

    test 'upload_snapshot raises RateLimited when image exceeds 16 MB' do
      assert_raises(RateLimited) do
        @client.upload_snapshot('x' * (16.megabytes + 1))
      end
    end

    test 'upload_snapshot raises Error on connection failure' do
      Net::HTTP.stub(:start, ->(*_args, **_kwargs, &_block) { raise Errno::ECONNREFUSED }) do
        assert_raises(Error) do
          @client.upload_snapshot('JPEG-BYTES')
        end
      end
    end

    test 'upload_snapshot raises Error on other failures' do
      stub_http(StubResponse.new(Net::HTTPBadRequest, '400')) do
        assert_raises(Error) do
          @client.upload_snapshot('JPEG-BYTES')
        end
      end
    end

    private

    StubResponse = Struct.new(:klass, :code) do
      def self.ok
        new(Net::HTTPOK, '200')
      end

      def build
        response = klass.new('1.1', code, klass.name.demodulize)
        response.instance_variable_set(:@read, true)
        response
      end
    end

    def stub_http(stub_response)
      captured = {}
      fake_http = Object.new
      fake_http.define_singleton_method(:request) do |request|
        captured[:request] = request
        stub_response.build
      end

      Net::HTTP.stub(:start, lambda { |*_args, **_kwargs, &block|
        block.call(fake_http)
      }) do
        yield(captured)
      end
    end
  end
end
