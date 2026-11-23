# The print a person standing at a printer would act on: the one printing now, or else the
# most recent print if it is still waiting to be cleared off the bed.
class ActionableJobs
  def self.by_printer(printers)
    new(printers).by_printer
  end

  def initialize(printers)
    @printer_ids = printers.map(&:id)
  end

  def by_printer
    active = latest_per_printer(Job.active)
    latest = latest_per_printer(Job.all)
    @printer_ids.index_with do |printer_id|
      active[printer_id] || latest[printer_id]&.then { |job| job.clearable? ? job : nil }
    end
  end

  private

  # One row per printer (Postgres DISTINCT ON), newest first in the same order as Job.recent,
  # so a kiosk polling the printer list never loads the whole print history.
  def latest_per_printer(scope)
    scope.where(printer_id: @printer_ids)
         .select('DISTINCT ON (jobs.printer_id) jobs.*')
         .reorder(Arel.sql('jobs.printer_id, jobs.started_at DESC, jobs.created_at DESC'))
         .preload(:owner, :cleared_by, :printer)
         .index_by(&:printer_id)
  end
end
