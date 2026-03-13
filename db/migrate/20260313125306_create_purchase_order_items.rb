class CreatePurchaseOrderItems < ActiveRecord::Migration[7.2]
  def change
    create_table :purchase_order_items do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.references :variant_pricing, null: false, foreign_key: true
      t.decimal :quantity
      t.string :unit
      t.decimal :unit_cost

      t.timestamps
    end
  end
end
