require 'test_helper'

class JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @job = jobs(:active_xl)
  end

  test 'index is accessible to everyone' do
    get jobs_path

    assert_response :success
  end

  test 'show is accessible to everyone' do
    get job_path(@job)

    assert_response :success
  end

  test 'show renders temperature chart when telemetry exists' do
    get job_path(@job)

    assert_select '.h-section-label', text: 'Temperatures'
    assert_match(/chart/i, response.body)
  end

  test 'show renders print preview and camera snapshot when attached' do
    attach_job_images(@job)

    get job_path(@job)

    assert_match(/Print preview/, response.body)
    assert_match(/Camera/, response.body)
  end

  test 'show omits temperature chart when job has no telemetry' do
    job = jobs(:finished)

    get job_path(job)

    assert_select '.h-section-label', text: 'Temperatures', count: 0
  end

  test 'My prints filter shows only the current user\'s jobs' do
    login_as(users(:viewer))
    get jobs_path(owner: 'me')

    assert_response :success
    assert_select 'h1', text: /My prints/
  end

  test 'anonymous users cannot claim a job' do
    patch claim_job_path(@job)

    assert_redirected_to login_path
  end

  test 'logged-in user can claim an unowned job' do
    @job.update!(owner: nil)
    login_as(users(:viewer))

    patch claim_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_equal users(:viewer).id, @job.reload.owner_id
  end

  test 'a user can release their own claim' do
    @job.update!(owner: users(:viewer))
    login_as(users(:viewer))

    delete claim_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_nil @job.reload.owner_id
  end

  test 'a non-admin cannot release someone else\'s claim' do
    @job.update!(owner: users(:other_viewer))
    login_as(users(:viewer))

    delete claim_job_path(@job)

    assert_response :forbidden
    assert_equal users(:other_viewer).id, @job.reload.owner_id
  end

  test 'an admin can release anyone\'s claim' do
    @job.update!(owner: users(:other_viewer))
    login_as(users(:admin))

    delete claim_job_path(@job)

    assert_redirected_to job_path(@job)
    assert_nil @job.reload.owner_id
  end

  test 'update owner is admin-only' do
    login_as(users(:viewer))
    patch job_path(@job), params: { job: { owner_id: users(:other_viewer).id } }

    assert_response :forbidden

    login_as(users(:admin))
    patch job_path(@job), params: { job: { owner_id: users(:other_viewer).id } }

    assert_redirected_to job_path(@job)
    assert_equal users(:other_viewer).id, @job.reload.owner_id
  end

  private

  def attach_job_images(job)
    job.preview_image.attach(
      io: StringIO.new('preview-bytes'),
      filename: 'preview.png',
      content_type: 'image/png'
    )
    job.camera_snapshot.attach(
      io: StringIO.new('camera-bytes'),
      filename: 'camera.jpg',
      content_type: 'image/jpeg'
    )
  end
end
