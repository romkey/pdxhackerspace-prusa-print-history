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

    test 'logs pretty printed JSON for json responses' do
      payload = { 'printer' => { 'state' => 'IDLE' } }
      logs = capture_prusalink_logs do
        stub_http(StubResponse.ok(payload.to_json)) do
          @client.status
        end
      end

      assert_match(%r{\[PrusaLink JSON\].*GET /api/v1/status}, logs)
      assert_match(/"state": "IDLE"/, logs)
    end

    test 'logs binary fetch size without dumping body' do
      logs = capture_prusalink_logs do
        stub_http(StubResponse.ok('PNG-BYTES')) do
          @client.download('/api/thumbnails/local/foo.gcode.orig.png')
        end
      end

      assert_match(/\[PrusaLink binary\].*9 bytes/, logs)
      assert_no_match(/PNG-BYTES/, logs)
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

    test 'pause, resume and stop use the job endpoints' do
      stub_http(StubResponse.ok('')) do |captured|
        @client.pause_job(7)

        assert_equal 'PUT /api/v1/job/7/pause', "#{captured[:request].method} #{captured[:request].path}"
        @client.resume_job(7)

        assert_equal 'PUT /api/v1/job/7/resume', "#{captured[:request].method} #{captured[:request].path}"
        @client.stop_job(7)

        assert_equal 'DELETE /api/v1/job/7', "#{captured[:request].method} #{captured[:request].path}"
        assert_equal 'abc-123', captured[:request]['X-Api-Key']
      end
    end

    test 'upload_file PUTs the stream with print-after-upload' do
      stub_http(StubResponse.ok('')) do |captured|
        @client.upload_file(StringIO.new('G28'), filename: 'my part.gcode', size: 3)
        request = captured[:request]

        assert_equal 'PUT /api/v1/files/usb/my%20part.gcode', "#{request.method} #{request.path}"
        assert_equal '?1', request['Print-After-Upload']
        assert_equal 'abc-123', request['X-Api-Key']
        assert_equal '3', request['Content-Length']
      end
    end

    test 'upload_file raises on failure' do
      stub_http(StubResponse.new(Net::HTTPConflict, '409')) do
        assert_raises(Error) { @client.upload_file(StringIO.new('x'), filename: 'a.gcode', size: 1) }
      end
    end

    test 'control commands raise on failure' do
      stub_http(StubResponse.new(Net::HTTPConflict, '409')) do
        assert_raises(Error) { @client.pause_job(7) }
      end
    end

    test 'translates network errors to Error' do
      Net::HTTP.stub(:start, ->(*_args, **_kwargs, &_block) { raise Errno::ECONNREFUSED }) do
        err = assert_raises(Error) { @client.status }
        assert_match(/ECONNREFUSED/, err.message)
      end
    end

    test 'translates host unreachable to Error instead of raising it' do
      Net::HTTP.stub(:start, ->(*_args, **_kwargs, &_block) { raise Errno::EHOSTUNREACH }) do
        err = assert_raises(Error) { @client.status }
        assert_match(/EHOSTUNREACH/, err.message)
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

    def capture_prusalink_logs
      io = StringIO.new
      old_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(io)
      yield
      io.string
    ensure
      Rails.logger = old_logger
    end

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
