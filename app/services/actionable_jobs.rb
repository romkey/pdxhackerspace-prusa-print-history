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

  def latest_per_printer(scope)
    scope.where(printer_id: @printer_ids)
         .includes(:owner, :cleared_by, :printer)
         .reorder(started_at: :desc, created_at: :desc)
         .to_a
         .group_by(&:printer_id)
         .transform_values(&:first)
  end
end
