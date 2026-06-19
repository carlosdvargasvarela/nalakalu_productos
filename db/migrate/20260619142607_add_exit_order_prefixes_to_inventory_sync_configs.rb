class AddExitOrderPrefixesToInventorySyncConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :inventory_sync_configs, :exit_order_prefixes, :text
  end
end
