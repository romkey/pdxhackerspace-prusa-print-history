class AdminConstraint
  def matches?(request)
    user_id = request.session[:user_id]
    return false if user_id.blank?

    user = User.find_by(id: user_id)
    user.present? && user.admin?
  end
end
