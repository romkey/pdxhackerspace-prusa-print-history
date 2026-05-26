require 'test_helper'

module PrusaLink
  class ClientTest < ActiveSupport::TestCase
    setup do
      @printer = printers(:prusa_xl)
      @printer.update!(prusalink_key: 'abc-123')
      @client = Client.new(@printer)
    end

    test 'status returns parsed JSON on 200' do
      stub_http(StubResponse.ok({ 'state' => 'PRINTING' }.to_json)) do |captured|
        assert_equal({ 'state' => 'PRINTING' }, @client.status)
        assert_equal '/api/v1/status', captured[:request].path
      end
    end

    test 'request carries the X-Api-Key header' do
      stub_http(StubResponse.ok('{}')) do |captured|
        @client.status

        assert_equal 'abc-123', captured[:request]['X-Api-Key']
        assert_equal 'application/json', captured[:request]['Accept']
      end
    end

    test 'job returns nil on 404 (no job present)' do
      stub_http(StubResponse.new(Net::HTTPNotFound, '404')) do
        assert_nil @client.job
      end
    end

    test 'raises Error on non-success' do
      stub_http(StubResponse.new(Net::HTTPInternalServerError, '500')) do
        err = assert_raises(Error) { @client.status }
        assert_match(/500/, err.message)
      end
    end

    test 'translates network errors to Error' do
      Net::HTTP.stub(:start, ->(*_args, **_kwargs, &_block) { raise Errno::ECONNREFUSED }) do
        err = assert_raises(Error) { @client.status }
        assert_match(/ECONNREFUSED/, err.message)
      end
    end

    test 'download returns binary body for thumbnail paths' do
      stub_http(StubResponse.ok('PNG-BYTES')) do |captured|
        body = @client.download('/api/thumbnails/local/foo.gcode.orig.png')

        assert_equal 'PNG-BYTES', body
        assert_equal '/api/thumbnails/local/foo.gcode.orig.png', captured[:request].path
        assert_equal 'abc-123', captured[:request]['X-Api-Key']
      end
    end

    test 'download returns nil for blank path' do
      assert_nil @client.download(nil)
    end

    test 'camera_snapshot returns binary body' do
      stub_http(StubResponse.ok('PNG-BYTES')) do |captured|
        body = @client.camera_snapshot

        assert_equal 'PNG-BYTES', body
        assert_equal '/api/v1/cameras/snap', captured[:request].path
      end
    end

    test 'camera_snapshot returns nil when camera is unavailable' do
      stub_http(StubResponse.new(Net::HTTPNotFound, '404')) do
        assert_nil @client.camera_snapshot
      end
    end

    private

    StubResponse = Struct.new(:klass, :code, :body) do
      def self.ok(body)
        new(Net::HTTPOK, '200', body)
      end

      def build
        response = klass.new('1.1', code, klass.name.demodulize)
        response.instance_variable_set(:@read, true)
        response.body = body if body
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

      stub_start = lambda do |*_args, **_kwargs, &block|
        block.call(fake_http)
      end

      Net::HTTP.stub(:start, stub_start) do
        yield(captured)
      end
    end
  end
end
