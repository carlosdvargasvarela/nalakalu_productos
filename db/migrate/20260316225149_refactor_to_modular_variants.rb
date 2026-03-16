# db/migrate/20260316000001_refactor_to_modular_variants.rb
class RefactorToModularVariants < ActiveRecord::Migration[7.2]
  def change
    # 1. Tablas para EAV (Atributos Modulares)
    create_table :properties do |t|
      t.string :name, null: false
      t.boolean :active, default: true
      t.timestamps
    end
    add_index :properties, :name, unique: true

    create_table :property_values do |t|
      t.references :property, null: false, foreign_key: true
      t.string :value, null: false
      t.boolean :active, default: true
      t.timestamps
    end
    add_index :property_values, [:property_id, :value], unique: true

    create_table :variant_properties do |t|
      t.references :variant, null: false, foreign_key: true
      t.references :property_value, null: false, foreign_key: true
      t.timestamps
    end
    add_index :variant_properties, [:variant_id, :property_value_id], unique: true

    # 2. Evolución de Compatibilities
    # Actualmente solo relaciona Variante con Variante.
    # Añadimos polimorfismo para que una Variante sea compatible con un Producto o una Familia.
    add_column :compatibilities, :compatible_type, :string, default: "Variant"
    rename_column :compatibilities, :compatible_variant_id, :compatible_id

    # 3. Precios por Producto (Opcional pero recomendado si el precio cambia por mueble)
    create_table :product_variant_prices do |t|
      t.references :product, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.decimal :price, precision: 15, scale: 2
      t.timestamps
    end
  end
end
