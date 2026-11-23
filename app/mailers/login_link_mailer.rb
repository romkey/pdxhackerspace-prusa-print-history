class LoginLinkMailer < ApplicationMailer
  SUBJECTS = {
    'sign_in' => 'Your sign-in link',
    'problem_report' => 'Your link to report a printer problem'
  }.freeze

  def sign_in_link(user, url, expires_at, purpose = 'sign_in')
    @user = user
    @url = url
    @expires_at = expires_at
    @purpose = purpose
    mail(to: user.email, subject: SUBJECTS.fetch(purpose, SUBJECTS['sign_in']))
  end
end
