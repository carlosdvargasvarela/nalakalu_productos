class CleanupLegacyProcurementColumns < ActiveRecord::Migration[7.2]
  def up
    # =========================================================
    # VARIANTS
    # La variante deja de ser una pieza comprable.
    # Ya no debe guardar proveedor ni SKU de proveedor.
    # =========================================================
    if foreign_key_exists?(:variants, :providers)
      remove_foreign_key :variants, :providers
    end

    if index_exists?(:variants, :provider_id)
      remove_index :variants, :provider_id
    end

    remove_column :variants, :provider_id, :integer if column_exists?(:variants, :provider_id)
    remove_column :variants, :provider_sku, :string if column_exists?(:variants, :provider_sku)

    # =========================================================
    # PURCHASE ORDER ITEMS
    # La línea de orden de compra debe apuntar siempre a supplier_item.
    # variant_id queda obsoleto en la nueva arquitectura.
    # =========================================================
    if foreign_key_exists?(:purchase_order_items, :variants)
      remove_foreign_key :purchase_order_items, :variants
    end

    if index_exists?(:purchase_order_items, :variant_id)
      remove_index :purchase_order_items, :variant_id
    end

    remove_column :purchase_order_items, :variant_id, :integer if column_exists?(:purchase_order_items, :variant_id)

    change_column_null :purchase_order_items, :supplier_item_id, false

    # =========================================================
    # PRODUCT VARIANT PRICES
    # Esta tabla pertenece al modelo anterior y no se está usando.
    # =========================================================
    drop_table :product_variant_prices if table_exists?(:product_variant_prices)
  end

  def down
    # =========================================================
    # VARIANTS
    # =========================================================
    add_column :variants, :provider_id, :integer unless column_exists?(:variants, :provider_id)
    add_column :variants, :provider_sku, :string unless column_exists?(:variants, :provider_sku)

    unless index_exists?(:variants, :provider_id)
      add_index :variants, :provider_id
    end

    unless foreign_key_exists?(:variants, :providers)
      add_foreign_key :variants, :providers
    end

    # =========================================================
    # PURCHASE ORDER ITEMS
    # =========================================================
    add_column :purchase_order_items, :variant_id, :integer unless column_exists?(:purchase_order_items, :variant_id)

    unless index_exists?(:purchase_order_items, :variant_id)
      add_index :purchase_order_items, :variant_id
    end

    unless foreign_key_exists?(:purchase_order_items, :variants)
      add_foreign_key :purchase_order_items, :variants
    end

    change_column_null :purchase_order_items, :supplier_item_id, true

    # =========================================================
    # PRODUCT VARIANT PRICES
    # =========================================================
    unless table_exists?(:product_variant_prices)
      create_table :product_variant_prices do |t|
        t.integer :product_id, null: false
        t.integer :variant_id, null: false
        t.decimal :price, precision: 15, scale: 2
        t.timestamps
      end

      add_index :product_variant_prices, :product_id
      add_index :product_variant_prices, :variant_id

      add_foreign_key :product_variant_prices, :products
      add_foreign_key :product_variant_prices, :variants
    end
  end
end
