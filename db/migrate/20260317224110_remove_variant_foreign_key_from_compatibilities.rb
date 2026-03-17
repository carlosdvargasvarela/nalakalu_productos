class RemoveVariantForeignKeyFromCompatibilities < ActiveRecord::Migration[7.2]
  def change
    # Eliminamos por nombre de tabla destino (como está definida en schema.rb)
    remove_foreign_key :compatibilities, :variants, column: :compatible_id

    # Reemplazamos el índice único simple por uno que incluya el tipo
    remove_index :compatibilities, [:variant_id, :compatible_id] if index_exists?(:compatibilities, [:variant_id, :compatible_id])

    add_index :compatibilities, [:compatible_type, :compatible_id]
    add_index :compatibilities,
      [:variant_id, :compatible_id, :compatible_type],
      name: "index_compatibilities_unique_composite",
      unique: true
  end
end
