require 'test_helper'

class PrinterCameraTest < ActiveSupport::TestCase
  setup do
    @with_camera    = printers(:prusa_xl)
    @without_camera = printers(:prusa_mini)
  end

  test 'returns nil when the printer has no camera configured' do
    assert_nil PrinterCamera.snapshot(@without_camera)
  end

  test 'returns IO/filename/content-type on success' do
    stub_response = build_ok_response('JPEG-BYTES', 'image/jpeg')

    result = PrinterCamera.allocate
    result.instance_variable_set(:@printer, @with_camera)
    result.instance_variable_set(:@timeout, 1)
    result.define_singleton_method(:fetch) { |_url| stub_response }

    snapshot = result.snapshot

    assert_kind_of Hash, snapshot
    assert_equal 'image/jpeg', snapshot[:content_type]
    assert_match(/^printer_\d+_\d+\.jpg$/, snapshot[:filename])
    assert_equal 'JPEG-BYTES', snapshot[:io].read
  end

  test 'returns nil when the fetch raises a network error' do
    result = PrinterCamera.allocate
    result.instance_variable_set(:@printer, @with_camera)
    result.instance_variable_set(:@timeout, 1)
    result.define_singleton_method(:fetch) { |_url| raise Errno::ECONNREFUSED }

    assert_nil result.snapshot
  end

  test 'returns nil for non-success responses' do
    not_found = Net::HTTPNotFound.new('1.1', '404', 'Not Found')

    result = PrinterCamera.allocate
    result.instance_variable_set(:@printer, @with_camera)
    result.instance_variable_set(:@timeout, 1)
    result.define_singleton_method(:fetch) { |_url| not_found }

    assert_nil result.snapshot
  end

  test 'uses basic auth from camera URL when configured' do
    captured_request = nil
    response = build_ok_response('JPEG-BYTES', 'image/jpeg')
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |req|
      captured_request = req
      response
    end

    printer = printers(:prusa_xl)
    printer.camera_url = 'http://user:pass@printer.local/snapshot.jpg'

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(fake_http) }) do
      PrinterCamera.snapshot(printer)
    end

    assert_match(/\ABasic /, captured_request['Authorization'])
  end

  test 'uses PrusaLink camera snap when no camera URL is configured' do
    @without_camera.update!(prusalink_key: 'secret', camera_url: nil)
    client = Object.new
    client.define_singleton_method(:camera_snapshot) { 'PNG-BYTES' }

    snapshot = PrinterCamera.snapshot(@without_camera, client: client)

    assert_equal 'image/png', snapshot[:content_type]
    assert_equal 'PNG-BYTES', snapshot[:io].read
  end

  private

  def build_ok_response(body, content_type)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response.instance_variable_set(:@read, true)
    response['Content-Type'] = content_type
    response.body = body
    response
  end
end
