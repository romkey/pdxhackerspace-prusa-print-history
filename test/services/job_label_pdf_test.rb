require 'test_helper'

class JobLabelPdfTest < ActiveSupport::TestCase
  test 'renders job details into a PDF' do
    job = jobs(:active_xl)
    pdf = JobLabelPdf.new(job, thermal_width_mm: 80)

    output = pdf.render

    assert output.start_with?('%PDF')
    assert_operator output.bytesize, :>, 100
  end

  test 'includes owner before filename and other job details' do
    job = jobs(:active_xl)
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)

    assert_includes pdf_text, job.filename
    assert_includes pdf_text, job.owner.display_name
    assert_includes pdf_text, 'Prusa XL / PLA'
    assert_includes pdf_text, job.status.humanize
    assert_includes pdf_text, I18n.l(job.started_at, format: :short)
    assert_operator pdf_text.index(job.owner.display_name), :<, pdf_text.index(job.filename)
  end

  test 'uses larger owner title and body sizes than before' do
    job = jobs(:active_xl)
    pdf = JobLabelPdf.new(job, thermal_width_mm: 80)
    theme = pdf.send(:theme)

    assert_equal 30, theme[:owner]
    assert_equal 20, theme[:filename]
    assert_equal 14, theme[:body]
  end

  test 'uses portrait page with height at least roll width' do
    job = jobs(:active_xl)
    pdf = JobLabelPdf.new(job, thermal_width_mm: 80)
    doc = pdf.document
    media_box = doc.page.dictionary.data[:MediaBox]
    width_pt = JobLabelPdf.mm_to_pt(80)

    assert_equal [0, 0], media_box.values_at(0, 1)
    assert_in_delta pdf.page_height_pt, media_box[3], 0.5
    assert_in_delta width_pt, media_box[2], 0.5
    assert_operator pdf.page_height_pt, :>=, width_pt
    assert_operator pdf.page_height_pt, :<, 400
  end

  test 'does not pass custom cups media size' do
    job = jobs(:active_xl)
    pdf = JobLabelPdf.new(job, thermal_width_mm: 80)

    assert_empty pdf.cups_media_options
  end

  test 'does not include organization header or field labels' do
    job = jobs(:active_xl)
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)

    assert_not_includes pdf_text, 'Prusa Print History'
    assert_not_includes pdf_text, 'Owner:'
    assert_not_includes pdf_text, 'Printer:'
    assert_not_includes pdf_text, 'Material:'
    assert_not_includes pdf_text, 'Print time:'
    assert_not_includes pdf_text, 'Status:'
  end

  test 'shows unclaimed when job has no owner' do
    job = jobs(:orphaned_active)
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)

    assert_includes pdf_text, 'Unclaimed'
    assert_includes pdf_text, 'Prusa MK4 / ASA'
  end

  private

  def extract_pdf_text(pdf_bytes)
    pdf_bytes.scan(/<[0-9a-fA-F]+>/).flat_map do |hex|
      hex.delete('<>').scan(/../).map { |pair| pair.hex.chr }
    end.join
  end
end
