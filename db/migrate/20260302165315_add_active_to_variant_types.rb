class AddActiveToVariantTypes < ActiveRecord::Migration[7.2]
  def change
    add_column :variant_types, :active, :boolean, default: true, null: false
  end
end
