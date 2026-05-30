require 'test_helper'

class EventsControllerTest < ActionDispatch::IntegrationTest
  test 'index requires sign-in from outside the internal network' do
    get events_path, headers: external_request_headers

    assert_redirected_to login_path
  end

  test 'index is accessible on the internal network' do
    get events_path

    assert_response :success
    assert_select 'h1', text: 'Events'
  end

  test 'index hides pagination when all events fit on one page' do
    get events_path

    assert_response :success
    assert_select 'a[href*="page="]', count: 0
  end

  test 'index shows pagination when events span multiple pages' do
    job = jobs(:active_xl)
    25.times do |index|
      job.events.create!(
        event_type: 'status_changed',
        to_status: 'printing',
        occurred_at: index.minutes.ago
      )
    end

    get events_path

    assert_response :success
    assert_select 'a[href*="page=2"]', minimum: 1
  end

  test 'index lists job and printer events' do
    get events_path

    assert_match(/Filament change/, response.body)
    assert_match(/Started/i, response.body)
    assert_match jobs(:active_xl).filename, response.body
    assert_match printers(:prusa_xl).name, response.body
  end

  test 'index shows filter chips' do
    get events_path

    assert_select 'a.filter-chip', text: 'Start'
    assert_select 'a.filter-chip', text: 'End'
    assert_select 'a.filter-chip', text: 'Attention'
    assert_select 'a.filter-chip', text: 'Filament change'
  end

  test 'filter chips limit results' do
    get events_path, params: { filter: ['filament_change'] }

    assert_response :success
    assert_match(/Filament change/, response.body)
    assert_no_match(/Started/i, response.body)
  end

  test 'navbar includes events link' do
    get root_path

    assert_select 'a.nav-link', text: 'Events'
  end
end
