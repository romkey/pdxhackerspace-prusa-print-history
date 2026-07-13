require 'test_helper'

module PrusaConnect
  class PhotoUploadTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @printer = printers(:prusa_xl)
      @printer.update!(
        prusa_connect_token: 'camera-token-12345678',
        prusa_connect_fingerprint: 'fingerprint-abc'
      )
      @capture = @printer.photo_captures.create!(captured_at: Time.current)
      @capture.image.attach(
        io: StringIO.new('JPEG-BYTES'),
        filename: 'camera.jpg',
        content_type: 'image/jpeg'
      )
    end

    test 'enqueue! schedules upload when printer has Prusa Connect token' do
      assert_enqueued_with(
        job: PrusaConnectPhotoUploadJob,
        args: [@printer.id, 'PhotoCapture', @capture.id]
      ) do
        PhotoUpload.enqueue!(@printer, @capture)
      end
    end

    test 'enqueue! does nothing without Prusa Connect token' do
      @printer.update!(prusa_connect_token: nil, prusa_connect_fingerprint: nil)

      assert_no_enqueued_jobs only: PrusaConnectPhotoUploadJob do
        PhotoUpload.enqueue!(@printer, @capture)
      end
    end

    test 'upload! sends image when rate limit allows' do
      client = Minitest::Mock.new
      client.expect(:upload_snapshot, true, ['JPEG-BYTES'], content_type: 'image/jpeg')

      freeze_time do
        PhotoUpload.upload!(@printer, body: 'JPEG-BYTES', client: client)

        assert_equal Time.current, @printer.reload.prusa_connect_last_uploaded_at
      end

      client.verify
    end

    test 'upload! skips when recently uploaded' do
      @printer.update!(prusa_connect_last_uploaded_at: 5.seconds.ago)
      called = false
      client = Object.new
      client.define_singleton_method(:upload_snapshot) do |*_args, **_kwargs|
        called = true
      end

      PhotoUpload.upload!(@printer, body: 'JPEG-BYTES', client: client)

      assert_not called
      assert_in_delta 5.seconds.ago.to_f, @printer.reload.prusa_connect_last_uploaded_at.to_f, 1.0
    end

    test 'upload! skips when printer has no Prusa Connect token' do
      @printer.update!(prusa_connect_token: nil, prusa_connect_fingerprint: nil)
      called = false
      client = Object.new
      client.define_singleton_method(:upload_snapshot) do |*_args, **_kwargs|
        called = true
      end

      PhotoUpload.upload!(@printer, body: 'JPEG-BYTES', client: client)

      assert_not called
    end

    test 'rate_limited? is false after minimum upload interval' do
      @printer.update!(prusa_connect_last_uploaded_at: 11.seconds.ago)

      assert_not PhotoUpload.rate_limited?(@printer)
    end

    test 'rate_limited? is true within minimum upload interval' do
      @printer.update!(prusa_connect_last_uploaded_at: 9.seconds.ago)

      assert PhotoUpload.rate_limited?(@printer)
    end

    test 'upload! handles remote rate limiting without raising' do
      client = Object.new
      client.define_singleton_method(:upload_snapshot) do |_body, **|
        raise RateLimited, 'too many requests'
      end

      assert_nothing_raised do
        PhotoUpload.upload!(@printer, body: 'JPEG-BYTES', client: client)
      end

      assert_nil @printer.reload.prusa_connect_last_uploaded_at
    end
  end
end
