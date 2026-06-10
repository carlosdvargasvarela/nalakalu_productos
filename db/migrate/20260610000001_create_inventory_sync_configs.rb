class CreateInventorySyncConfigs < ActiveRecord::Migration[7.2]
  def change
    create_table :inventory_sync_configs do |t|
      # Defaults para el formulario manual de sync
      t.integer :default_days_back,    default: 7,     null: false
      t.integer :default_days_forward, default: 0,     null: false

      # Sync automático programado
      t.boolean :schedule_enabled,     default: false, null: false
      t.string  :schedule_cron,        default: "0 6 * * *"
      t.integer :schedule_days_back,   default: 14,    null: false

      t.timestamps
    end
  end
end
