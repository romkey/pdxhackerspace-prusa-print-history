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

  test 'uses horizontal page layout sized to content without extra margins' do
    job = jobs(:active_xl)
    pdf = JobLabelPdf.new(job, thermal_width_mm: 80)
    doc = pdf.document
    media_box = doc.page.dictionary.data[:MediaBox]

    assert_equal [0, 0], media_box.values_at(0, 1)
    assert_operator pdf.page_width_pt, :>, pdf.page_height_pt
    assert_in_delta pdf.content_height_pt, pdf.page_height_pt, 0.5
    assert_in_delta pdf.page_width_pt, media_box[2], 0.5
    assert_in_delta pdf.page_height_pt, media_box[3], 0.5
  end

  test 'includes full filename without truncation' do
    job = jobs(:active_xl)
    job.filename = 'very_long_part_name_that_would_have_been_truncated_before.gcode'
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)

    assert_includes pdf_text, job.filename
    assert_not_includes pdf_text, '...'
  end

  test 'shows start and finish time on one line with day of week when same day' do
    job = jobs(:finished)
    start_time = Time.zone.parse('2026-05-28 10:00')
    end_time = Time.zone.parse('2026-05-28 12:00')
    job.update!(started_at: start_time, ended_at: end_time)
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)
    expected = "#{start_time.strftime('%a %b %-d, %H:%M')} - #{end_time.strftime('%H:%M')}"

    assert_includes pdf_text, expected
  end

  test 'repeats day of week when finish is on a different day' do
    job = jobs(:finished)
    start_time = Time.zone.parse('2026-05-28 22:00')
    end_time = Time.zone.parse('2026-05-29 02:00')
    job.update!(started_at: start_time, ended_at: end_time)
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)
    expected = "#{start_time.strftime('%a %b %-d, %H:%M')} - #{end_time.strftime('%a %b %-d, %H:%M')}"

    assert_includes pdf_text, expected
  end

  test 'shows start time with day of week when print has not ended' do
    job = jobs(:active_xl)
    start_time = job.started_at.in_time_zone
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)

    assert_includes pdf_text, start_time.strftime('%a %b %-d, %H:%M')
    assert_not_includes pdf_text, ' - '
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

  test 'keeps the owner name off the label of a private print' do
    job = jobs(:active_xl)
    job.update!(owner: users(:viewer), private: true)
    pdf_text = extract_pdf_text(JobLabelPdf.new(job, thermal_width_mm: 80).render)

    assert_not_includes pdf_text, users(:viewer).display_name
    assert_includes pdf_text, 'Private print'
    assert_includes pdf_text, job.filename
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
