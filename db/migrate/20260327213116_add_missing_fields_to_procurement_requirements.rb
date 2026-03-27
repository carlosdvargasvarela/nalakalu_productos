class AddMissingFieldsToProcurementRequirements < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:procurement_requirements, :supply_rule_id)
      add_column :procurement_requirements, :supply_rule_id, :integer
    end

    unless column_exists?(:procurement_requirements, :origin_products)
      add_column :procurement_requirements, :origin_products, :json, default: []
    end

    unless index_exists?(:procurement_requirements, :supply_rule_id)
      add_index :procurement_requirements, :supply_rule_id
    end
  end
end
