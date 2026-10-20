class GeneralizeSupplierLinks < ActiveRecord::Migration[7.2]
  # Un vínculo pieza <-> (producto y/o variante):
  #   solo variante       -> la variante se compra con ese código en cualquier producto (textiles)
  #   producto + variante -> la pieza depende de ambos (sobre en fibra F1 de la mesa X)
  #   solo producto       -> la pieza es del producto sin importar la variante
  def change
    rename_table :product_supplier_items, :supplier_links
    remove_index :supplier_links, name: "index_product_supplier_items_unique" # impedía producto + variantes distintas
    change_column_null :supplier_links, :product_id, true
    add_reference :supplier_links, :variant, foreign_key: true
    add_column :variant_types, :own_supplier_code, :boolean, default: false, null: false
  end
end
