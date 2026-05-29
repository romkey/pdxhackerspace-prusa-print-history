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
      filename: (20 * s).round,
      owner: (15 * s).round,
      body: (9 * s).round,
      gap: 4
    }
  end

  def generate
    t = theme
    render_filename(t)
    document.move_down t[:gap]
    render_owner(t)
    document.move_down t[:gap]
    render_line(t[:body], printer_material_line)
    render_line(t[:body], @job.status.humanize)
    render_line(t[:body], print_time_label)
  end

  def render_filename(theme_values)
    document.font_size(theme_values[:filename]) do
      document.text truncate_filename(@job.filename), align: :center, style: :bold
    end
  end

  def render_owner(theme_values)
    document.font_size(theme_values[:owner]) do
      document.text @job.owner&.display_name || 'Unclaimed', align: :center, style: :bold
    end
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

  def trim_page
    used_height = THERMAL_INITIAL_HEIGHT - document.cursor + THERMAL_MARGIN
    w = @thermal_width_pt
    document.page.dictionary.data[:MediaBox] = [0, 0, w, used_height]
    document.page.dictionary.data[:CropBox] = [0, 0, w, used_height]
  end
end
