require 'prawn'

class JobLabelPdf
  THERMAL_MARGIN = 10
  THERMAL_MARGIN_TOP = THERMAL_MARGIN / 2
  THERMAL_INITIAL_HEIGHT = 800

  def self.mm_to_pt(width_mm)
    width_mm.to_f * 72.0 / 25.4
  end

  def initialize(job, thermal_width_mm: 80)
    @job = job
    @thermal_width_mm = thermal_width_mm.to_i
    @thermal_width_pt = self.class.mm_to_pt(@thermal_width_mm)
    @document = Prawn::Document.new(document_options)
    generate
    trim_page
  end

  attr_reader :document

  delegate :render, to: :document

  private

  def document_options
    {
      page_size: [@thermal_width_pt, THERMAL_INITIAL_HEIGHT],
      margin: [THERMAL_MARGIN_TOP, THERMAL_MARGIN, THERMAL_MARGIN, THERMAL_MARGIN]
    }
  end

  def thermal_font_scale
    (@thermal_width_mm.to_f / 80.0).clamp(0.85, 1.25)
  end

  def theme
    s = thermal_font_scale
    {
      org: (8 * s).round,
      title: (14 * s).round,
      body: (9 * s).round,
      field: (8 * s).round,
      gap: 4
    }
  end

  def generate
    render_header
    render_metadata
  end

  def render_header
    theme_values = theme
    draw_org_line(theme_values)
    draw_filename_title(theme_values)
    document.stroke_horizontal_rule
    document.move_down theme_values[:gap]
  end

  def draw_org_line(theme_values)
    org = ENV.fetch('ORGANIZATION_NAME', 'Prusa Print History')
    document.font_size(theme_values[:org]) { document.text org, align: :center, color: '444444' }
    document.move_down theme_values[:gap]
  end

  def draw_filename_title(theme_values)
    document.font_size(theme_values[:title]) do
      document.text truncate_filename(@job.filename), align: :center, style: :bold
    end
    document.move_down theme_values[:gap]
  end

  def render_metadata
    field('Owner', @job.owner&.display_name || 'Unclaimed')
    field('Printer', @job.printer.name)
    field('Material', material_summary)
    field('Print time', print_time_label)
    field('Status', @job.status.humanize)
  end

  def field(label, value)
    t = theme
    document.font_size(t[:field]) do
      document.text "<b>#{label}:</b> #{value}", inline_format: true
    end
    document.move_down 2
  end

  def material_summary
    materials = @job.tools.filter_map(&:material).uniq
    return '—' if materials.empty?

    materials.join(', ')
  end

  def print_time_label
    time = @job.started_at || @job.created_at
    I18n.l(time, format: :short)
  end

  def truncate_filename(name)
    name.to_s.length > 40 ? "#{name[0, 37]}..." : name
  end

  def trim_page
    used_height = THERMAL_INITIAL_HEIGHT - document.cursor + THERMAL_MARGIN
    w = @thermal_width_pt
    document.page.dictionary.data[:MediaBox] = [0, 0, w, used_height]
    document.page.dictionary.data[:CropBox] = [0, 0, w, used_height]
  end
end
