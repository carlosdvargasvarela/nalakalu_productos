class CreateFamilyVariantRules < ActiveRecord::Migration[7.2]
  def change
    create_table :family_variant_rules do |t|
      t.references :family, null: false, foreign_key: true
      t.references :variant_type, null: false, foreign_key: true
      t.integer :position
      t.boolean :required, default: true
      t.string :separator, default: "-"
      t.string :label

      t.timestamps
    end
  end
end
