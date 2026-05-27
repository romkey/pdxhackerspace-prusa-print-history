require 'test_helper'

class PrinterLiveBroadcasterTest < ActionView::TestCase
  include ApplicationHelper

  test 'live panel uses relative active storage paths without example.com host' do
    job = jobs(:active_xl)
    job.preview_image.attach(
      io: StringIO.new('preview-bytes'),
      filename: 'preview.png',
      content_type: 'image/png'
    )
    capture = job.printer.photo_captures.create!(captured_at: Time.current)
    capture.image.attach(
      io: StringIO.new('camera-bytes'),
      filename: 'camera.jpg',
      content_type: 'image/jpeg'
    )

    Rails.application.routes.default_url_options = { host: 'example.com', protocol: 'http' }

    html = AppUrl.with_url_options do
      render partial: 'printers/live_panel',
             locals: PrinterShowPresenter.new(job.printer).locals
    end

    assert_includes html, '/rails/active_storage/blobs/'
    assert_not_includes html, 'example.com'
    assert_match(/Print preview/, html)
  ensure
    Rails.application.routes.default_url_options = {}
  end
end
