require 'test_helper'

class ArControllerTest < ActionDispatch::IntegrationTest
  test 'requires sign-in from outside the internal network' do
    get ar_path, headers: external_request_headers

    assert_redirected_to login_path
  end

  test 'is accessible on the internal network' do
    get ar_path

    assert_response :success
    assert_select 'a-scene', count: 1
  end

  test 'is accessible to logged in users from outside the internal network' do
    login_as(users(:viewer))
    get ar_path, headers: external_request_headers

    assert_response :success
  end

  test 'renders without the application navbar layout' do
    get ar_path

    assert_response :success
    assert_select 'nav.navbar', count: 0
  end

  test 'renders one marker per printer mapped to its id' do
    printers = Printer.ordered.to_a

    get ar_path

    assert_response :success
    assert_select 'a-marker[data-printer-id]', count: printers.size
    printers.each_with_index do |printer, index|
      assert_select "a-marker[data-printer-id='#{printer.id}'][url='/ar/markers/marker-#{index}.patt']"
    end
  end

  test 'caps markers at the number of available marker patterns' do
    (Printer.count...(ArController::MARKER_COUNT + 3)).each do |n|
      Printer.create!(name: "Extra Printer #{n}", hostname: "extra-#{n}.local")
    end

    assert_operator Printer.count, :>, ArController::MARKER_COUNT

    get ar_path

    assert_response :success
    assert_select 'a-marker[data-printer-id]', count: ArController::MARKER_COUNT
  end

  test 'exposes printers and status url to the AR config' do
    get ar_path

    assert_match(/window\.AR_CONFIG/, response.body)
    assert_match(%r{statusUrl: "/printers\.json"}, response.body)
    assert_match printers(:prusa_xl).name, response.body
  end

  test 'preview panel offers current and preview tabs' do
    get ar_path

    assert_response :success
    assert_select '.phud__preview-tabs [data-view="current"]', text: 'Current'
    assert_select '.phud__preview-tabs [data-view="preview"]', text: 'Preview'
  end

  test 'loads the AR scripts and stylesheet' do
    get ar_path

    assert_select 'script[src="/ar/js/ar-printer.js"]'
    assert_select 'link[href="/ar/css/printer-status.css"]'
    assert_select 'script[src*="aframe"]'
  end

  test 'navbar includes the AR link' do
    get root_path

    assert_select 'a.nav-link', text: 'AR'
  end
end
