class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.string :name
      t.string :base_code
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
