require 'prawn'

class JobLabelPdf
  THERMAL_MARGIN = 10
  THERMAL_MARGIN_TOP = THERMAL_MARGIN / 2
  TRIM_TAIL_LINES = 4

  def self.mm_to_pt(width_mm)
    width_mm.to_f * 72.0 / 25.4
  end

  def initialize(job, thermal_width_mm: 80)
    @job = job
    @thermal_width_mm = thermal_width_mm.to_i
    @thermal_width_pt = self.class.mm_to_pt(@thermal_width_mm)
    @theme = theme
    @page_height_pt = compute_page_height_pt
    @document = Prawn::Document.new(
      page_size: [@thermal_width_pt, @page_height_pt],
      margin: margins
    )
    generate
  end

  attr_reader :document, :page_height_pt

  delegate :render, to: :document

  def cups_media_options
    {}
  end

  private

  def margins
    [THERMAL_MARGIN_TOP, THERMAL_MARGIN, THERMAL_MARGIN, THERMAL_MARGIN]
  end

  def page_height_mm
    (@page_height_pt * 25.4 / 72.0).ceil
  end

  def compute_page_height_pt
    content = THERMAL_MARGIN_TOP + content_height_pt + tail_padding_pt + THERMAL_MARGIN
    [content, @thermal_width_pt].max
  end

  def content_height_pt
    measure { |doc| content_line_heights(doc, @theme).sum }
  end

  def content_line_heights(doc, theme_values)
    [
      text_block_height(doc, theme_values[:owner], owner_text, bold: true),
      theme_values[:gap],
      text_block_height(doc, theme_values[:filename], truncate_filename(@job.filename), bold: true),
      theme_values[:gap],
      text_block_height(doc, theme_values[:body], printer_material_line) + 2,
      text_block_height(doc, theme_values[:body], @job.status.humanize) + 2,
      text_block_height(doc, theme_values[:body], print_time_label) + 2
    ]
  end

  def tail_padding_pt
    measure { |doc| tail_padding(doc, @theme[:body], TRIM_TAIL_LINES) }
  end

  def measure
    doc = Prawn::Document.new(page_size: [@thermal_width_pt, 100], margin: margins)
    yield doc
  end

  def text_block_height(doc, size, text, bold: false)
    doc.font_size(size) do
      options = { align: :center }
      options[:style] = :bold if bold
      doc.height_of(text, **options)
    end
  end

  def thermal_font_scale
    (@thermal_width_mm.to_f / 80.0).clamp(0.85, 1.25)
  end

  def theme
    s = thermal_font_scale
    title_size = (20 * s).round
    {
      owner: (title_size * 1.5).round,
      filename: title_size,
      body: (9 * s * 1.5).round,
      gap: 4
    }
  end

  def generate
    t = @theme
    render_owner(t)
    document.move_down t[:gap]
    render_filename(t)
    document.move_down t[:gap]
    render_line(t[:body], printer_material_line)
    render_line(t[:body], @job.status.humanize)
    render_line(t[:body], print_time_label)
    document.move_down tail_padding(document, t[:body], TRIM_TAIL_LINES)
  end

  def render_filename(theme_values)
    document.font_size(theme_values[:filename]) do
      document.text truncate_filename(@job.filename), align: :center, style: :bold
    end
  end

  def render_owner(theme_values)
    document.font_size(theme_values[:owner]) do
      document.text owner_text, align: :center, style: :bold
    end
  end

  def owner_text
    @job.owner&.display_name || 'Unclaimed'
  end

  def render_line(size, text)
    document.font_size(size) do
      document.text text, align: :center
    end
    document.move_down 2
  end

  def printer_material_line
    "#{@job.printer.name} / #{material_summary}"
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

  def tail_padding(doc, font_size, lines)
    doc.font_size(font_size) do
      doc.height_of('X') * lines
    end
  end
end
