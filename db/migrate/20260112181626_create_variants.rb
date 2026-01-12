class CreateVariants < ActiveRecord::Migration[7.2]
  def change
    create_table :variants do |t|
      t.references :variant_type, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true
      t.string :name
      t.string :code
      t.string :provider_sku
      t.decimal :cost
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
