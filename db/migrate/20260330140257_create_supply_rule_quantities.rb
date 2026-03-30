class CreateSupplyRuleQuantities < ActiveRecord::Migration[7.1]
  def change
    create_table :supply_rule_quantities do |t|
      t.references :supply_rule, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity_needed, precision: 10, scale: 4, null: false, default: 1.0

      t.timestamps
    end

    add_index :supply_rule_quantities, [:supply_rule_id, :product_id], unique: true
  end
end
