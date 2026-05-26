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

  private

  def build_ok_response(body, content_type)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response.instance_variable_set(:@read, true)
    response['Content-Type'] = content_type
    response.body = body
    response
  end
end
