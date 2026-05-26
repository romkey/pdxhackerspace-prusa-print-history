require 'test_helper'

class JobImageCaptureTest < ActiveSupport::TestCase
  setup do
    @job = jobs(:active_xl)
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

  private

  def stub_client(download:)
    obj = Object.new
    obj.define_singleton_method(:download) { |_path| download }
    obj
  end
end
