class DashboardPresenter
  ATTENTION_OUTLINE_STATUSES = %w[paused attention error].freeze
  EXCLUSIVE_STATUS_FILTERS = %w[idle printing attention].freeze
  STATUS_FILTERS = (EXCLUSIVE_STATUS_FILTERS + %w[offline]).freeze
  SPECIAL_FILTERS = (STATUS_FILTERS + %w[my_prints]).freeze

  Card = Struct.new(:printer, :current_job, :last_job, :heads, :snapshot, :latest_reading, keyword_init: true) do
    def idle?
      current_job.nil?
    end

    def printing?
      current_job&.active?
    end

    def preview_job
      current_job || last_job
    end

    def preview_attached?
      preview_job&.preview_image&.attached?
    end

    def snapshot_attached?
      snapshot&.image&.attached?
    end

    def primary_head
      heads.first
    end

    def material_label
      primary_head&.material.presence || '---'
    end

    def nozzle_label
      return '---' unless primary_head

      "#{primary_head.nozzle_size_mm.to_f.round(1)}mm"
    end

    def bed_temp_c
      latest_reading&.bed_temp
    end

    def nozzle_temp_c
      latest_reading&.tool_temp(0)
    end

    def enclosure_temp_c
      latest_reading&.enclosure_temp || printer.enclosure_temp
    end

    def ambient_temp_c
      latest_reading&.ambient_temp || printer.ambient_temp
    end

    def image_outline_status
      status = printer.display_status
      return 'printing' if status == 'printing'
      return 'ready' if status == 'idle'
      return 'ready' if printer.prusalink_connection_status == :reachable &&
                        DashboardPresenter::ATTENTION_OUTLINE_STATUSES.exclude?(status)

      'attention'
    end
  end

  attr_reader :recent_events, :active_filters

  def initialize(printers:, active_jobs_by_printer:, last_jobs_by_printer:, recent_events:, **options)
    @printers = printers
    @active_jobs_by_printer = active_jobs_by_printer
    @last_jobs_by_printer = last_jobs_by_printer
    @recent_events = recent_events
    @current_user = options[:current_user]
    @active_filters = normalize_filters(options.fetch(:filters, []))
  end

  def cards
    @cards ||= @printers.map { |printer| build_card(printer) }
  end

  def filtered_cards
    return cards if active_filters.empty?

    cards.select { |card| matches_filters?(card) }
  end

  def material_filters
    @material_filters ||= cards.flat_map { |card| card.heads.map(&:material) }.compact_blank.uniq.sort
  end

  def printer_count
    @printers.size
  end

  def active_job_count
    @active_jobs_by_printer.size
  end

  private

  def normalize_filters(raw_filters)
    selected = Array(raw_filters).map(&:to_s).compact_blank
    selected -= ['my_prints'] unless @current_user
    selected -= ['available']
    exclusive = selected & EXCLUSIVE_STATUS_FILTERS
    if exclusive.size > 1
      selected = selected - EXCLUSIVE_STATUS_FILTERS + [exclusive.last]
    end
    allowed = SPECIAL_FILTERS + material_filters
    selected.select { |filter| allowed.include?(filter) }
  end

  def matches_filters?(card)
    active_filters.all? { |filter| matches_filter?(card, filter) }
  end

  def matches_filter?(card, filter)
    case filter
    when 'attention' then card_attention?(card)
    when 'idle' then card_idle?(card)
    when 'printing' then card_printing?(card)
    when 'offline' then card_offline?(card)
    when 'my_prints' then card_my_print?(card)
    else card_material?(card, filter)
    end
  end

  def card_attention?(card)
    card.printer.prusalink_connection_status == :reachable &&
      ATTENTION_OUTLINE_STATUSES.include?(card.printer.display_status)
  end

  def card_idle?(card)
    card.printer.prusalink_connection_status == :reachable &&
      card.printer.display_status == 'idle'
  end

  def card_printing?(card)
    card.printer.prusalink_connection_status == :reachable &&
      card.printer.display_status == 'printing'
  end

  def card_offline?(card)
    card.printer.prusalink_connection_status != :reachable
  end

  def card_my_print?(card)
    return false unless @current_user

    job = card.current_job || card.last_job
    job&.owner_id == @current_user.id
  end

  def card_material?(card, material)
    card.heads.any? { |head| head.material == material }
  end

  def build_card(printer)
    job = @active_jobs_by_printer[printer.id]
    Card.new(
      printer: printer,
      current_job: job,
      last_job: job ? nil : @last_jobs_by_printer[printer.id],
      heads: printer.printer_heads.sort_by(&:tool_index),
      snapshot: latest_snapshot(printer, job),
      latest_reading: latest_reading(job)
    )
  end

  def latest_reading(job)
    return nil unless job

    job.telemetry_readings.order(:recorded_at).last
  end

  def latest_snapshot(printer, job)
    if job
      job.photo_captures.progress.reverse_chronological.first ||
        printer.photo_captures.idle.reverse_chronological.first
    else
      printer.photo_captures.idle.reverse_chronological.first
    end
  end
end
