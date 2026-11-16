require 'test_helper'

class PrinterReliabilityTest < ActiveSupport::TestCase
  setup do
    @printer = printers(:prusa_mini)
    @user = users(:viewer)
    Job.where(printer: @printer).destroy_all
  end

  test 'scores the last 90 days and skips printers with too few prints' do
    add_jobs(4)
    add_attention(1.day.ago)

    score = PrinterReliability.for_printer(@printer)

    assert_equal 1, score.attentions
    assert_nil score.display_score

    add_jobs(1)
    rated = PrinterReliability.for_printer(@printer)

    assert rated.rated?
    assert_equal 97, rated.display_score
  end

  test 'penalizes problems and repairs and ignores entries outside the window' do
    add_jobs(5)
    @printer.service_entries.create!(kind: 'problem', summary: 'Old', occurred_at: 100.days.ago, user: @user)
    @printer.service_entries.create!(kind: 'problem', summary: 'New', occurred_at: 2.days.ago, user: @user)
    @printer.service_entries.create!(kind: 'repair', summary: 'Fixed', occurred_at: 1.day.ago, user: @user)

    score = PrinterReliability.for_printer(@printer)

    assert_equal 1, score.problems
    assert_equal 1, score.repairs
    assert_equal 87, score.display_score
  end

  test 'attentions during an outage do not count, including an outage that is still open' do
    job = add_jobs(5).first
    @printer.service_entries.create!(kind: 'out_of_service', summary: 'Hotend', occurred_at: 5.days.ago, user: @user)
    @printer.service_entries.create!(
      kind: 'back_in_service', summary: 'Back in service', occurred_at: 4.days.ago, user: @user
    )
    @printer.service_entries.create!(kind: 'out_of_service', summary: 'Board', occurred_at: 2.days.ago, user: @user)
    add_attention_on(job, 6.days.ago)
    add_attention_on(job, 4.5.days.ago)
    add_attention_on(job, 1.day.ago)
    add_attention_on(job, 100.days.ago)

    score = PrinterReliability.for_printer(@printer)

    assert_equal 1, score.attentions
    assert_equal 97, score.display_score
  end

  test 'an outage that started before the window still excludes attentions inside it' do
    job = add_jobs(5).first
    @printer.service_entries.create!(kind: 'out_of_service', summary: 'Away', occurred_at: 120.days.ago, user: @user)
    add_attention_on(job, 10.days.ago)

    score = PrinterReliability.for_printer(@printer)

    assert_equal 0, score.attentions
    assert_equal 100, score.display_score
  end

  test 'days out of service count only the overlap with the window' do
    @printer.service_entries.create!(kind: 'out_of_service', summary: 'Away', occurred_at: 100.days.ago, user: @user)
    @printer.service_entries.create!(
      kind: 'back_in_service', summary: 'Back', occurred_at: 80.days.ago, user: @user
    )

    score = PrinterReliability.for_printer(@printer)

    assert_equal 10, score.days_out
  end

  private

  def add_jobs(count)
    Array.new(count) do |index|
      @printer.jobs.create!(filename: "part-#{SecureRandom.hex(4)}-#{index}.gcode", status: 'finished',
                            started_at: 1.day.ago)
    end
  end

  def add_attention(occurred_at)
    add_attention_on(@printer.jobs.first, occurred_at)
  end

  def add_attention_on(job, occurred_at)
    job.events.create!(event_type: 'attention', occurred_at:)
  end
end
