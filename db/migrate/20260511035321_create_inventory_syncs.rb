class CreateInventorySyncs < ActiveRecord::Migration[7.2]
  def change
    create_table :inventory_syncs do |t|
      t.date :from_date, null: false
      t.date :to_date, null: false
      t.string :status, default: "pending_review", null: false
      t.integer :deliveries_processed, default: 0
      t.integer :movements_count, default: 0
      t.integer :unresolved_count, default: 0
      t.datetime :synced_at
      t.timestamps
    end

    add_index :inventory_syncs, :status
  end
end
