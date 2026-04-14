class CleanupSupplierItemSpecs < ActiveRecord::Migration[7.2]
  def up
    # ✅ eliminar índice SI existe (forma segura)
    begin
      remove_index :supplier_item_properties, name: "index_sip_unique_variant"
    rescue
      # no existe, ignorar
    end

    # ✅ eliminar foreign keys si existen
    if foreign_key_exists?(:supplier_item_properties, :variants, column: :variant_id)
      remove_foreign_key :supplier_item_properties, column: :variant_id
    end

    if foreign_key_exists?(:supplier_item_properties, :variant_types, column: :variant_type_id)
      remove_foreign_key :supplier_item_properties, column: :variant_type_id
    end

    # ✅ eliminar columnas
    remove_column :supplier_item_properties, :variant_type_id if column_exists?(:supplier_item_properties, :variant_type_id)
    remove_column :supplier_item_properties, :variant_id if column_exists?(:supplier_item_properties, :variant_id)

    # ✅ asegurar default correcto
    change_column_default :supplier_item_properties, :spec_type, "property"
  end

  def down
    add_column :supplier_item_properties, :variant_type_id, :integer
    add_column :supplier_item_properties, :variant_id, :integer

    add_foreign_key :supplier_item_properties, :variant_types, column: :variant_type_id
    add_foreign_key :supplier_item_properties, :variants, column: :variant_id

    add_index :supplier_item_properties,
      [:supplier_item_id, :variant_id],
      unique: true,
      where: "variant_id IS NOT NULL",
      name: "index_sip_unique_variant"
  end
end
