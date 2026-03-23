# Genera una migración: rails g migration AddPositionToVariantTypes position:integer
class AddPositionToVariantTypes < ActiveRecord::Migration[7.1]
  def change
    add_column :variant_types, :position, :integer, default: 0
  end
end
