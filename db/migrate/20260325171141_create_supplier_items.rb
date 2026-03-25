class CreateSupplierItems < ActiveRecord::Migration[7.2]
  def change
    create_table :supplier_items do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :name, null: false
      t.string :sku
      t.string :unit, default: "unidad"
      t.decimal :default_cost, precision: 15, scale: 2
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :supplier_items, [:provider_id, :sku], unique: true, where: "sku IS NOT NULL"
  end
end
