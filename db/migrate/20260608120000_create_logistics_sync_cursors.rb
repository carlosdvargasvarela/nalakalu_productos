class CreateLogisticsSyncCursors < ActiveRecord::Migration[7.2]
  def change
    create_table :logistics_sync_cursors do |t|
      t.datetime :last_synced_at
      t.timestamps
    end
  end
end
