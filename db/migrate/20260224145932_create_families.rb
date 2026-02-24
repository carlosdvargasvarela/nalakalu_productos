class CreateFamilies < ActiveRecord::Migration[7.2]
  def change
    create_table :families do |t|
      t.string :name
      t.text :description
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
