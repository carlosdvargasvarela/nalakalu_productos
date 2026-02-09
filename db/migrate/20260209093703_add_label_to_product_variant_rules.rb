class AddLabelToProductVariantRules < ActiveRecord::Migration[7.2]
  def change
    add_column :product_variant_rules, :label, :string
  end
end