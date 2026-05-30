require 'test_helper'

class EventListingTest < ActiveSupport::TestCase
  test 'returns job and printer events ordered by occurred_at desc' do
    events = EventListing.new(filters: []).results

    assert events.any?
    assert_equal events, events.sort_by(&:occurred_at).reverse
    assert(events.any? { |event| event.record.is_a?(JobEvent) })
    assert(events.any? { |event| event.record.is_a?(PrinterEvent) })
  end

  test 'filters to started events only' do
    events = EventListing.new(filters: ['start']).results

    assert(events.all? { |event| event.record.is_a?(JobEvent) && event.record.event_type == 'started' })
  end

  test 'filters to finished events only' do
    events = EventListing.new(filters: ['end']).results

    assert(events.all? { |event| event.record.is_a?(JobEvent) && event.record.event_type == 'finished' })
  end

  test 'filters to attention events only' do
    events = EventListing.new(filters: ['attention']).results

    assert(events.all? { |event| event.record.is_a?(JobEvent) && event.record.event_type == 'attention' })
  end

  test 'filters to filament change events only' do
    events = EventListing.new(filters: ['filament_change']).results

    assert(events.all? { |event| event.record.is_a?(PrinterEvent) })
    assert_equal 'filament_change', events.first.record.event_type
  end

  test 'combines multiple filters with union semantics' do
    events = EventListing.new(filters: %w[start filament_change]).results
    types = events.map { |event| event.record.is_a?(JobEvent) ? event.record.event_type : 'filament_change' }

    assert_includes types, 'started'
    assert_includes types, 'filament_change'
  end

  test 'paginates twenty events per page' do
    job = jobs(:active_xl)
    25.times do |index|
      job.events.create!(
        event_type: 'status_changed',
        to_status: 'printing',
        occurred_at: index.minutes.ago
      )
    end

    assert_operator EventListing.new(filters: []).total_count, :>=, 25
    assert_equal 20, EventListing.new(filters: []).results(page: 1).size
    assert_operator EventListing.new(filters: []).results(page: 2).size, :>=, 1
  end
end
