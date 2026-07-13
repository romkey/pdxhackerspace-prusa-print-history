module PrintTimeReportUserRowLabeler
  module_function

  def call(rows)
    users_by_id = User.where(id: rows.map(&:key)).index_by { |user| user.id.to_s }

    rows.map do |row|
      user = users_by_id[row.key]
      user ? row.with(label: user.display_name) : row
    end
  end
end
