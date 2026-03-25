# rails g migration UpdateEavToSupplierItems
class UpdateEavToSupplierItems < ActiveRecord::Migration[7.2]
  def change
    # 1. Eliminamos la relación vieja con variantes
    drop_table :variant_properties if table_exists?(:variant_properties)

    # 2. Creamos la nueva relación con SupplierItems
    create_table :supplier_item_properties do |t|
      t.references :supplier_item, null: false, foreign_key: true
      t.references :property_value, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end

    # Aseguramos que una pieza no tenga el mismo valor de propiedad dos veces
    add_index :supplier_item_properties, [:supplier_item_id, :property_value_id],
      unique: true,
      name: "index_supplier_item_props_unique"
  end
end
