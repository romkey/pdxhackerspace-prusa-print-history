require 'test_helper'

class PrinterPhotoCaptureTest < ActiveSupport::TestCase
  setup do
    @printer = printers(:prusa_xl)
    @job = jobs(:active_xl)
    @snapshot = {
      io: StringIO.new('JPEG-BYTES'),
      filename: 'camera.jpg',
      content_type: 'image/jpeg'
    }
  end

  test 'stores progress photos for active jobs' do
    PrinterCamera.stub(:snapshot, @snapshot) do
      assert_difference -> { @job.photo_captures.progress.count } => 1 do
        PrinterPhotoCapture.capture!(@printer, job: @job)
      end
    end

    capture = @job.photo_captures.progress.last

    assert capture.image.attached?
    assert_equal 'JPEG-BYTES', capture.image.download
  end

  test 'keeps all progress photos while a job is active' do
    PrinterCamera.stub(:snapshot, @snapshot) do
      2.times { PrinterPhotoCapture.capture!(@printer, job: @job) }
    end

    assert_equal 2, @job.photo_captures.progress.count
  end

  test 'replaces idle photos when no job is active' do
    PrinterCamera.stub(:snapshot, @snapshot) do
      2.times { PrinterPhotoCapture.capture!(@printer, job: nil) }
    end

    assert_equal 1, @printer.photo_captures.idle.count
  end

  test 'does nothing when camera fetch fails' do
    PrinterCamera.stub(:snapshot, nil) do
      assert_no_difference -> { PhotoCapture.count } do
        PrinterPhotoCapture.capture!(@printer, job: @job)
      end
    end
  end
end
