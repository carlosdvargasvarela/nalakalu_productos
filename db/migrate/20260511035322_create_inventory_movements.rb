class CreateInventoryMovements < ActiveRecord::Migration[7.2]
  def change
    create_table :inventory_movements do |t|
      t.integer :inventory_sync_id
      t.integer :product_id
      t.integer :delivery_id
      t.integer :delivery_item_id
      t.date :delivery_date
      t.string :order_number
      t.string :client_name
      t.string :product_name_raw
      t.string :movement_type, null: false
      t.string :sala, null: false
      t.decimal :quantity, precision: 10, scale: 4, null: false, default: 1
      t.string :status, default: "resolved", null: false
      t.text :notes
      t.timestamps
    end

    add_index :inventory_movements, :inventory_sync_id
    add_index :inventory_movements, :product_id
    add_index :inventory_movements, :status
    add_index :inventory_movements, :movement_type
    add_index :inventory_movements, :delivery_id
    add_index :inventory_movements, %i[delivery_item_id movement_type sala],
      name: "index_inventory_movements_unique_item",
      unique: true,
      where: "delivery_item_id IS NOT NULL"

    add_foreign_key :inventory_movements, :inventory_syncs
    add_foreign_key :inventory_movements, :products
  end
end
