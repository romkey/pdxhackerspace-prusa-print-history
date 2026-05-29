require 'test_helper'

class JobLabelPdfTest < ActiveSupport::TestCase
  test 'renders job details into a PDF' do
    job = jobs(:active_xl)
    pdf = JobLabelPdf.new(job, thermal_width_mm: 80)

    output = pdf.render

    assert output.start_with?('%PDF')
    assert_operator output.bytesize, :>, 100
  end

  test 'includes filename owner printer material status and print time' do
    job = jobs(:active_xl)
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)

    assert_includes pdf_text, job.filename
    assert_includes pdf_text, job.owner.display_name
    assert_includes pdf_text, 'Prusa XL / PLA'
    assert_includes pdf_text, job.status.humanize
    assert_includes pdf_text, I18n.l(job.started_at, format: :short)
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
