class AddFamilyToProducts < ActiveRecord::Migration[7.2]
  def change
    add_reference :products, :family, null: true, foreign_key: true
  end
end
