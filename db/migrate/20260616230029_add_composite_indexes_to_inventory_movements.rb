class AddCompositeIndexesToInventoryMovements < ActiveRecord::Migration[7.2]
  def change
    add_index :inventory_movements, [:status, :product_id, :showroom_id],
              name: "index_inv_movements_on_status_product_showroom"
    add_index :inventory_movements, [:status, :showroom_id, :product_id],
              name: "index_inv_movements_on_status_showroom_product"
    add_index :inventory_movements, [:status, :delivery_date, :created_at],
              name: "index_inv_movements_on_status_delivery_date"
  end
end
