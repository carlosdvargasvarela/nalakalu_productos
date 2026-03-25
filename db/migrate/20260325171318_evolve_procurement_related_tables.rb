class EvolveProcurementRelatedTables < ActiveRecord::Migration[7.2]
  def change
    add_column :variant_types, :procurement_strategy, :string,
      default: "individual", null: false

    add_reference :purchase_order_items, :supplier_item, foreign_key: true, null: true

    add_column :purchase_order_items, :specifications, :json, default: {}, null: false

    change_column_null :purchase_order_items, :variant_id, true
  end
end
