require 'test_helper'

class CaptureEventPhotoJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    @event = job_events(:active_xl_started)
    @printer = @event.job.printer
    @snapshot = {
      io: StringIO.new('EVENT-JPEG'),
      filename: 'event.jpg',
      content_type: 'image/jpeg'
    }
  end

  test 'attaches snapshot to job event' do
    PrinterCamera.stub(:snapshot, @snapshot) do
      CaptureEventPhotoJob.perform_now(@event.id)
    end

    assert @event.reload.photo.attached?
    assert_equal 'EVENT-JPEG', @event.photo.download
  end

  test 'does nothing when photo is already attached' do
    @event.photo.attach(
      io: StringIO.new('EXISTING'),
      filename: 'existing.jpg',
      content_type: 'image/jpeg'
    )

    PrinterCamera.stub(:snapshot, ->(*) { flunk 'should not fetch snapshot' }) do
      CaptureEventPhotoJob.perform_now(@event.id)
    end

    assert_equal 'EXISTING', @event.photo.download
  end

  test 'does nothing when camera fetch fails' do
    PrinterCamera.stub(:snapshot, nil) do
      CaptureEventPhotoJob.perform_now(@event.id)
    end

    assert_not @event.reload.photo.attached?
  end

  test 'enqueues Prusa Connect upload when printer is configured' do
    @printer.update!(prusa_connect_token: 'camera-token-12345678')

    PrinterCamera.stub(:snapshot, @snapshot) do
      assert_enqueued_with(job: PrusaConnectPhotoUploadJob) do
        CaptureEventPhotoJob.perform_now(@event.id)
      end
    end
  end

  test 'does not enqueue Prusa Connect upload without token' do
    PrinterCamera.stub(:snapshot, @snapshot) do
      assert_no_enqueued_jobs only: PrusaConnectPhotoUploadJob do
        CaptureEventPhotoJob.perform_now(@event.id)
      end
    end
  end
end
