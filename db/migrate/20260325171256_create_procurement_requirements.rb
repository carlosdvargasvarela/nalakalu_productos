class CreateProcurementRequirements < ActiveRecord::Migration[7.2]
  def change
    create_table :procurement_requirements do |t|
      t.references :supplier_item, null: false, foreign_key: true
      t.references :purchase_order_item, foreign_key: true, null: true
      t.string :origin_order_number, null: false
      t.string :origin_delivery_id
      t.string :origin_product_name
      t.decimal :quantity, precision: 10, scale: 4, null: false
      t.json :specifications, default: {}, null: false
      t.string :status, default: "pending", null: false
      t.timestamps
    end

    add_index :procurement_requirements, :status
    add_index :procurement_requirements, :origin_order_number
    add_index :procurement_requirements,
      [:supplier_item_id, :origin_order_number],
      unique: true,
      name: "index_procurement_req_unique"

    if postgresql?
      add_index :procurement_requirements, :specifications, using: :gin
    end
  end

  private

  def postgresql?
    connection.adapter_name.downcase.include?("postgres")
  end
end
