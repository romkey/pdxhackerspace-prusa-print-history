class EventsController < ApplicationController
  before_action :require_login_or_internal, only: [:index]

  def index
    listing = EventListing.new(filters: params[:filter])
    @active_filters = listing.filters
    @pagy = Pagy::Offset.new(count: listing.total_count, page: params[:page], limit: EventListing::PAGE_SIZE,
                             request: Pagy::Request.new(request:))
    @events = listing.results(page: @pagy.page)
  end
end
