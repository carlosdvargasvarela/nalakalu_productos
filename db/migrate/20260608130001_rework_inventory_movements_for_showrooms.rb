class ReworkInventoryMovementsForShowrooms < ActiveRecord::Migration[7.2]
  def change
    remove_index :inventory_movements, name: "index_inventory_movements_unique_item"
    remove_column :inventory_movements, :sala, :string

    add_column :inventory_movements, :showroom_id, :integer
    add_column :inventory_movements, :source, :string, default: "synced", null: false
    add_column :inventory_movements, :flag, :string

    add_index :inventory_movements, :showroom_id
    add_index :inventory_movements, :source
    add_index :inventory_movements, :flag
    add_index :inventory_movements, %i[delivery_item_id movement_type showroom_id],
      name: "index_inventory_movements_unique_item",
      unique: true,
      where: "delivery_item_id IS NOT NULL"

    add_foreign_key :inventory_movements, :showrooms
  end
end
