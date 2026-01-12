class CreateProductVariantRules < ActiveRecord::Migration[7.2]
  def change
    create_table :product_variant_rules do |t|
      t.references :product, null: false, foreign_key: true
      t.references :variant_type, null: false, foreign_key: true
      t.integer :position
      t.boolean :required, default: true
      t.string :separator, default: "-"

      t.timestamps
    end
  end
end
