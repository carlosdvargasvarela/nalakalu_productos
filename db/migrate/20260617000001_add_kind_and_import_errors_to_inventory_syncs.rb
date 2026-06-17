class AddKindAndImportErrorsToInventorySyncs < ActiveRecord::Migration[7.2]
  def change
    add_column :inventory_syncs, :kind, :string, default: "logistics_sync", null: false
    add_column :inventory_syncs, :import_errors, :json, default: []
  end
end
