require 'test_helper'

class PrusaConnectPhotoUploadJobTest < ActiveJob::TestCase
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

  test 'uploads photo capture image to Prusa Connect' do
    uploaded = {}

    PrusaConnect::PhotoUpload.stub(:upload!, lambda { |printer, body:, content_type:, **|
      uploaded[:printer] = printer
      uploaded[:body] = body
      uploaded[:content_type] = content_type
    }) do
      PrusaConnectPhotoUploadJob.perform_now(@printer.id, 'PhotoCapture', @capture.id)
    end

    assert_equal @printer, uploaded[:printer]
    assert_equal 'JPEG-BYTES', uploaded[:body]
    assert_equal 'image/jpeg', uploaded[:content_type]
  end

  test 'uploads job event photo to Prusa Connect' do
    event = job_events(:active_xl_started)
    event.photo.attach(
      io: StringIO.new('EVENT-BYTES'),
      filename: 'event.jpg',
      content_type: 'image/jpeg'
    )

    uploaded = {}

    PrusaConnect::PhotoUpload.stub(:upload!, lambda { |printer, body:, content_type:, **|
      uploaded[:printer] = printer
      uploaded[:body] = body
      uploaded[:content_type] = content_type
    }) do
      PrusaConnectPhotoUploadJob.perform_now(@printer.id, 'JobEvent', event.id)
    end

    assert_equal @printer, uploaded[:printer]
    assert_equal 'EVENT-BYTES', uploaded[:body]
    assert_equal 'image/jpeg', uploaded[:content_type]
  end

  test 'does nothing when attachable has no image' do
    @capture.image.purge
    called = false

    PrusaConnect::PhotoUpload.stub(:upload!, ->(*) { called = true }) do
      PrusaConnectPhotoUploadJob.perform_now(@printer.id, 'PhotoCapture', @capture.id)
    end

    assert_not called
  end
end
