class CreateRecommendations < ActiveRecord::Migration[7.2]
  def change
    create_table :recommendations do |t|
      t.string :recommendation_type, null: false
      t.string :status, default: "pending", null: false
      t.integer :variant_type_id, null: false
      t.integer :product_id
      t.string :suggested_variant_name
      t.string :suggested_variant_code
      t.string :requester_name
      t.text :notes
      t.timestamps
    end

    add_index :recommendations, :variant_type_id
    add_index :recommendations, :product_id
    add_index :recommendations, :status
    add_foreign_key :recommendations, :variant_types
    add_foreign_key :recommendations, :products
  end
end
