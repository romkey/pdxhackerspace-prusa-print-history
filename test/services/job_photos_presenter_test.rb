require 'test_helper'

class JobPhotosPresenterTest < ActiveSupport::TestCase
  setup do
    @job = jobs(:active_xl)
  end

  test 'identifies initial and final progress photos' do
    attach_progress_photo(captured_at: 30.minutes.ago)
    attach_progress_photo(captured_at: 20.minutes.ago)
    attach_progress_photo(captured_at: 10.minutes.ago)

    presenter = JobPhotosPresenter.new(@job)

    assert_equal @job.photo_captures.chronological.first, presenter.initial_photo
    assert_equal @job.photo_captures.chronological.last, presenter.final_photo
    assert_equal 3, presenter.progress_photos.size
  end

  test 'latest_photo_label reflects active and finished jobs' do
    attach_progress_photo(captured_at: 30.minutes.ago)
    attach_progress_photo(captured_at: 10.minutes.ago)

    assert_equal 'Current', JobPhotosPresenter.new(@job).latest_photo_label

    @job.update!(status: 'finished', ended_at: Time.current)

    assert_equal 'Job finish', JobPhotosPresenter.new(@job).latest_photo_label
  end

  test 'returns only initial photo when job has one capture' do
    attach_progress_photo(captured_at: 10.minutes.ago)

    presenter = JobPhotosPresenter.new(@job)

    assert presenter.initial_photo
    assert_nil presenter.final_photo
  end

  test 'snapshot_photo returns the latest progress photo' do
    attach_progress_photo(captured_at: 30.minutes.ago)
    attach_progress_photo(captured_at: 10.minutes.ago)

    presenter = JobPhotosPresenter.new(@job)

    assert_equal @job.photo_captures.chronological.last, presenter.snapshot_photo
    assert presenter.snapshot_attached?
  end

  test 'snapshot_photo is nil without progress photos' do
    presenter = JobPhotosPresenter.new(jobs(:finished))

    assert_nil presenter.snapshot_photo
    assert_not presenter.snapshot_attached?
  end

  private

  def attach_progress_photo(captured_at:)
    capture = @job.photo_captures.create!(printer: @job.printer, captured_at: captured_at)
    capture.image.attach(
      io: StringIO.new('bytes'),
      filename: 'photo.jpg',
      content_type: 'image/jpeg'
    )
    capture
  end
end
