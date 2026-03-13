# db/migrate/20260313_create_variant_pricings.rb
class CreateVariantPricings < ActiveRecord::Migration[7.2]
  def change
    create_table :variant_pricings do |t|
      t.references :variant, null: false, foreign_key: true
      t.string :unit, null: false # ej: 'und', 'rol', 'mts'
      t.decimal :cost, precision: 15, scale: 2, default: 0.0
      t.boolean :is_default, default: false
      t.timestamps
    end
  end
end
