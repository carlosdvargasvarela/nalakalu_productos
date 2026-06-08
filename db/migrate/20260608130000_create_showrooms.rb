class CreateShowrooms < ActiveRecord::Migration[7.2]
  def change
    create_table :showrooms do |t|
      t.string  :name, null: false
      t.string  :code, null: false
      t.boolean :is_main, default: false, null: false
      t.text    :order_number_prefixes
      t.text    :order_number_keywords
      t.text    :inter_sala_keywords
      t.text    :product_keywords
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :showrooms, :code, unique: true
    add_index :showrooms, :is_main
    add_index :showrooms, :active
  end
end
