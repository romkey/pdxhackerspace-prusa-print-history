require 'test_helper'

class JobLabelPdfTest < ActiveSupport::TestCase
  test 'renders job details into a PDF' do
    job = jobs(:active_xl)
    pdf = JobLabelPdf.new(job, thermal_width_mm: 80)

    output = pdf.render

    assert output.start_with?('%PDF')
    assert_operator output.bytesize, :>, 100
  end

  test 'includes filename owner printer and material' do
    job = jobs(:active_xl)
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)

    assert_includes pdf_text, job.filename
    assert_includes pdf_text, job.owner.display_name
    assert_includes pdf_text, job.printer.name
    assert_includes pdf_text, 'PLA'
  end

  test 'shows unclaimed when job has no owner' do
    job = jobs(:orphaned_active)
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)

    assert_includes pdf_text, 'Unclaimed'
  end

  private

  def extract_pdf_text(pdf_bytes)
    pdf_bytes.scan(/<[0-9a-fA-F]+>/).flat_map do |hex|
      hex.delete('<>').scan(/../).map { |pair| pair.hex.chr }
    end.join
  end
end
