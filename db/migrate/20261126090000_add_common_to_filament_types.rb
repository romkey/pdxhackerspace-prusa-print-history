# Common filament types are shown first, and the only ones listed on the dashboard; the rest
# sit behind a "more" menu there.
class AddCommonToFilamentTypes < ActiveRecord::Migration[8.1]
  COMMON = %w[pla petg abs asa tpu].freeze

  def change
    add_column :filament_types, :common, :boolean, default: false, null: false

    reversible do |dir|
      dir.up { execute "UPDATE filament_types SET common = TRUE WHERE lower(name) IN (#{quoted_common})" }
    end
  end

  private

  def quoted_common
    COMMON.map { |name| connection.quote(name) }.join(', ')
  end
end
