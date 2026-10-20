class AddReviewWorkflow < ActiveRecord::Migration[7.2]
  def up
    add_column :products, :list_price, :decimal, precision: 15, scale: 2 # nil = sin precio

    create_table :reviews do |t|
      t.references :reviewable, polymorphic: true, null: false, index: false
      t.references :user, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.text :note
      t.timestamps
    end
    add_index :reviews, [:reviewable_type, :reviewable_id], unique: true

    create_table :product_supplier_items do |t|
      t.references :product, null: false, foreign_key: true
      t.references :supplier_item, null: false, foreign_key: true
      t.timestamps
    end
    add_index :product_supplier_items, [:product_id, :supplier_item_id], unique: true, name: "index_product_supplier_items_unique"

    # Las reglas de abastecimiento por producto ya vinculaban piezas con productos.
    execute <<~SQL
      INSERT INTO product_supplier_items (product_id, supplier_item_id, created_at, updated_at)
      SELECT DISTINCT product_id, supplier_item_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM supply_rules WHERE product_id IS NOT NULL
    SQL
  end

  def down
    drop_table :product_supplier_items
    drop_table :reviews
    remove_column :products, :list_price
  end
end
