class CreateProviders < ActiveRecord::Migration[7.2]
  def change
    create_table :providers do |t|
      t.string :name
      t.string :contact_name
      t.string :email
      t.string :phone
      t.text :notes
      t.boolean :active, default: true
      t.timestamps
    end
  end
end
