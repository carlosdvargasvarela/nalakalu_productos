class AddConsolidatedRuleUniquenessIndex < ActiveRecord::Migration[7.2]
  def change
    # Mejora búsqueda de reglas consolidadas por tipo y producto
    add_index :supply_rules, [:variant_type_id, :rule_type, :product_id],
      name: "index_supply_rules_on_consolidated_lookup",
      if_not_exists: true
  end
end
