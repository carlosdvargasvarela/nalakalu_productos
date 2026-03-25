class CreateSupplyRules < ActiveRecord::Migration[7.2]
  def change
    create_table :supply_rules do |t|
      t.references :product, foreign_key: true, null: true
      t.references :variant_type, null: false, foreign_key: true
      t.references :variant, foreign_key: true, null: true
      t.references :supplier_item, null: false, foreign_key: true
      t.decimal :quantity_needed, precision: 10, scale: 4, default: "1.0", null: false
      t.string :rule_type, default: "individual", null: false
      t.timestamps
    end

    add_index :supply_rules, [:product_id, :variant_id, :supplier_item_id],
      unique: true,
      name: "index_supply_rules_unique_composite"
  end
end
