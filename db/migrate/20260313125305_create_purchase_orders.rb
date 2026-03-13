class CreatePurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :purchase_orders do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :number
      t.date :issued_date
      t.date :delivery_deadline
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
