require 'prawn'

class JobLabelPdf
  SIDE_MARGIN = 4
  LINE_GAP = 2
  SECTION_GAP = 4

  def self.mm_to_pt(width_mm)
    width_mm.to_f * 72.0 / 25.4
  end

  def initialize(job, thermal_width_mm: 80)
    @job = job
    @thermal_width_mm = thermal_width_mm.to_i
    @theme = theme
    @lines = build_lines
    @content_width_pt = compute_content_width_pt
    @content_height_pt = compute_content_height_pt
    @page_width_pt = @content_width_pt + (SIDE_MARGIN * 2)
    @page_height_pt = @content_height_pt

    @document = Prawn::Document.new(
      page_size: [@page_width_pt, @page_height_pt],
      margin: [0, SIDE_MARGIN, 0, SIDE_MARGIN]
    )
    generate
  end

  attr_reader :document, :page_width_pt, :page_height_pt, :content_height_pt

  delegate :render, to: :document

  private

  # A private print's label carries neither the owner's name nor the filename; the printer
  # and the print times are what identify it on the pickup shelf.
  def build_lines
    t = @theme
    lines = [{ size: t[:owner], text: owner_text, bold: true }]
    lines << filename_line unless @job.private?

    lines + [
      { size: t[:body], text: printer_material_line, gap_before: SECTION_GAP },
      { size: t[:body], text: @job.status.humanize },
      { size: t[:body], text: print_time_label }
    ]
  end

  def filename_line
    { size: @theme[:filename], text: @job.filename.to_s, bold: true, gap_before: SECTION_GAP }
  end

  def compute_content_width_pt
    measure { |doc| @lines.map { |line| text_width(doc, line) }.max }
  end

  def compute_content_height_pt
    measure do |doc|
      @lines.each_with_index.sum do |line, index|
        height = line_height(doc, line)
        height += line[:gap_before] if line[:gap_before]
        height += LINE_GAP unless index == @lines.length - 1
        height
      end
    end
  end

  def measure
    doc = Prawn::Document.new(page_size: [1000, 1000], margin: [0, SIDE_MARGIN, 0, SIDE_MARGIN])
    yield doc
  end

  def text_width(doc, line)
    doc.font_size(line[:size])
    options = line[:bold] ? { style: :bold } : {}
    doc.width_of(line[:text], **options)
  end

  def line_height(doc, line)
    doc.font_size(line[:size])
    options = line[:bold] ? { style: :bold } : {}
    doc.height_of(line[:text], **options)
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
      body: (9 * s * 1.5).round
    }
  end

  def generate
    y = @page_height_pt

    @lines.each_with_index do |line, index|
      y -= line[:gap_before] if line[:gap_before]
      line_height = line_height_for(line)
      y -= line_height

      document.font_size(line[:size]) do
        options = {
          at: [0, y + line_height],
          width: @content_width_pt,
          height: line_height,
          align: :center,
          valign: :top
        }
        options[:style] = :bold if line[:bold]
        document.text_box line[:text], **options
      end

      y -= LINE_GAP unless index == @lines.length - 1
    end
  end

  def line_height_for(line)
    measure { |doc| line_height(doc, line) }
  end

  def owner_text
    return 'Private print' if @job.private?

    @job.owner&.display_name || 'Unclaimed'
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
    start_time = @job.started_at || @job.created_at
    return '—' unless start_time

    if @job.ended_at
      format_time_range(start_time, @job.ended_at)
    else
      format_time_with_day(start_time)
    end
  end

  def format_time_range(start_time, end_time)
    if same_day?(start_time, end_time)
      "#{format_time_with_day(start_time)} - #{format_time_only(end_time)}"
    else
      "#{format_time_with_day(start_time)} - #{format_time_with_day(end_time)}"
    end
  end

  def format_time_with_day(time)
    time.in_time_zone.strftime('%a %b %-d, %H:%M')
  end

  def format_time_only(time)
    time.in_time_zone.strftime('%H:%M')
  end

  def same_day?(first, second)
    first.in_time_zone.to_date == second.in_time_zone.to_date
  end
end
