class AddDeliveryStatusToInventoryMovements < ActiveRecord::Migration[7.2]
  def change
    add_column :inventory_movements, :delivery_status, :string
    add_index  :inventory_movements, :delivery_status
  end
end
