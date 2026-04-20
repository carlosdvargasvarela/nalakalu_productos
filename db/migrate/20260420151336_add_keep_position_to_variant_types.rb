# db/migrate/YYYYMMDDHHMMSS_add_keep_position_to_variant_types.rb
class AddKeepPositionToVariantTypes < ActiveRecord::Migration[7.2]
  def change
    add_column :variant_types, :keep_position, :boolean, default: false, null: false
  end
end
