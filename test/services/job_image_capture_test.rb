require 'test_helper'

class JobImageCaptureTest < ActiveSupport::TestCase
  setup do
    @job = jobs(:active_xl)
    @printer = @job.printer
    @job_payload = {
      'file' => {
        'refs' => {
          'thumbnail' => '/api/thumbnails/local/foo.gcode.orig.png'
        }
      }
    }
  end

  test 'captures preview image once from PrusaLink thumbnail ref' do
    client = stub_client(download: 'PNG-BYTES')

    assert_not @job.preview_image.attached?

    JobImageCapture.capture_preview!(@job, @job_payload, client: client)

    assert @job.preview_image.attached?
    assert_equal 'image/png', @job.preview_image.content_type

    assert_no_changes -> { @job.preview_image.blob.id } do
      JobImageCapture.capture_preview!(@job, @job_payload, client: stub_client(download: 'OTHER'))
    end
  end

  test 'falls back to icon ref when thumbnail is missing' do
    payload = { 'file' => { 'refs' => { 'icon' => '/api/thumbnails/local/foo.gcode.small.png' } } }
    client = stub_client(download: 'PNG-BYTES')

    JobImageCapture.capture_preview!(@job, payload, client: client)

    assert @job.preview_image.attached?
  end

  test 'captures camera snapshot for active jobs when camera is configured' do
    snapshot = {
      io: StringIO.new('JPEG-BYTES'),
      filename: 'printer_1_123.jpg',
      content_type: 'image/jpeg'
    }

    PrinterCamera.stub(:snapshot, snapshot) do
      JobImageCapture.capture_camera_snapshot!(@job, printer: @printer)
    end

    assert @job.camera_snapshot.attached?
  end

  test 'does not capture camera snapshot for finished jobs' do
    @job.update!(status: 'finished', ended_at: Time.current)

    PrinterCamera.stub(:snapshot, ->(*) { flunk 'camera should not be called' }) do
      JobImageCapture.capture_camera_snapshot!(@job, printer: @printer)
    end

    assert_not @job.camera_snapshot.attached?
  end

  private

  def stub_client(download:)
    obj = Object.new
    obj.define_singleton_method(:download) { |_path| download }
    obj
  end
end
