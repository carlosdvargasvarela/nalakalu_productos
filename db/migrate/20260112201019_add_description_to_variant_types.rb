class AddDescriptionToVariantTypes < ActiveRecord::Migration[7.2]
  def change
    add_column :variant_types, :description, :text
  end
end
