class CreateQbItems < ActiveRecord::Migration[7.2]
  # Copia de solo lectura del export de ítems de QuickBooks (fuente de verdad para códigos, precios y costos).
  def change
    create_table :qb_items do |t|
      t.string :code, null: false
      t.string :description
      t.string :raw_description
      t.string :item_type
      t.decimal :cost, precision: 15, scale: 2
      t.decimal :price, precision: 15, scale: 2
      t.string :vendor
      t.string :unit
      t.timestamps
    end
    add_index :qb_items, :code, unique: true

    add_column :supplier_items, :source, :string # nil = creada a mano; "quickbooks" = importada
  end
end
