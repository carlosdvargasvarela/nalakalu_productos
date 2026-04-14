# db/migrate/TIMESTAMP_extend_supplier_item_properties.rb
class ExtendSupplierItemProperties < ActiveRecord::Migration[7.2]
  def change
    change_table :supplier_item_properties do |t|
      t.string :label                          # "F1", "F2", "Ancho", etc.
      t.integer :variant_type_id                # catálogo de variantes a usar
      t.integer :variant_id                     # variante seleccionada
      t.string :spec_type, default: "property" # "property" | "variant_spec"
    end

    change_column_null :supplier_item_properties, :property_value_id, true

    add_foreign_key :supplier_item_properties, :variant_types, column: :variant_type_id
    add_foreign_key :supplier_item_properties, :variants, column: :variant_id

    # Índice para evitar duplicados dentro del mismo tipo
    add_index :supplier_item_properties,
      [:supplier_item_id, :variant_id],
      unique: true,
      where: "variant_id IS NOT NULL",
      name: "index_sip_unique_variant"
  end
end
