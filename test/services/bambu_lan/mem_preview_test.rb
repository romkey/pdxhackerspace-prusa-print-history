require 'test_helper'

class BambuLanMemPreviewTest < ActiveSupport::TestCase
  test 'assembles the printer preview jpeg and skips the metadata chunk' do
    jpeg = "\xFF\xD8\xFFplate".b
    socket = FakeSocket.new(replies(jpeg))

    bytes = BambuLan::MemPreview::Session.new(socket, code: 'abcd1234').preview

    assert_equal jpeg, bytes
    assert_includes socket.written, 'abcd1234'
    assert_includes socket.written, 'mem:/26'
  end

  test 'stops when the printer refuses the preview' do
    payload = JSON.generate('result' => 2, 'reply' => {})
    socket = FakeSocket.new(login_ack + setup_ack + frame(payload))

    error = assert_raises(BambuLan::Error) do
      BambuLan::MemPreview::Session.new(socket, code: 'abcd1234').preview
    end

    assert_match(/unavailable \(2\)/, error.message)
  end

  private

  def replies(jpeg)
    meta = "#{JSON.generate('result' => 1, 'reply' => { 'mem_dl_param_size' => 12, 'size' => 0 })}\n\n{\"result\":0}"
    part = "#{JSON.generate('result' => 1, 'reply' => { 'size' => jpeg.bytesize })}\n\n#{jpeg}"
    done = JSON.generate('result' => 0, 'reply' => { 'size' => 0, 'file_md5' => 'abc' })
    login_ack + setup_ack + frame(meta) + frame(part) + frame(done)
  end

  def login_ack
    frame("\0\0\0\0", magic: 0x0001013f, sequence: 1)
  end

  def setup_ack
    frame(JSON.generate('mtype' => 12_291, 'sequence' => 0, 'result' => 0, 'reply' => {}))
  end

  def frame(payload, magic: 0x0002013f, sequence: 3)
    [payload.bytesize, magic, sequence, 0].pack('V4') + payload.b
  end

  class FakeSocket
    attr_reader :written

    def initialize(inbound)
      @inbound = inbound.b
      @written = +''.b
    end

    def write(data)
      @written << data.b
    end

    def readpartial(count)
      raise IOError, 'eof' if @inbound.empty?

      @inbound.slice!(0, count)
    end
  end
end
