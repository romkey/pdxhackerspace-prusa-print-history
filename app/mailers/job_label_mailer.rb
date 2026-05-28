class JobLabelMailer < ApplicationMailer
  def print_ready(job)
    @job = job
    @owner = job.owner

    mail(
      to: @owner.email,
      subject: "Print ready: #{job.filename}"
    )
  end
end
