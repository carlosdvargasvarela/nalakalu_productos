class CreateCompatibilities < ActiveRecord::Migration[7.0]
  def change
    create_table :compatibilities do |t|
      t.references :variant, null: false, foreign_key: true
      t.references :compatible_variant, null: false, foreign_key: { to_table: :variants }

      t.timestamps
    end

    add_index :compatibilities, [:variant_id, :compatible_variant_id], unique: true
  end
end