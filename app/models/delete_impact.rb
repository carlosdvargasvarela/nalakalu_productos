class DeleteImpact
  # [[texto, cantidad, se_pierde?]] de lo que se afecta al eliminar un registro
  def self.for(r)
    case r
    when Product
      rules = r.product_variant_rules
      [["reglas de código (tipos de variante) del producto", rules.count, true],
        ["variantes permitidas dentro de esas reglas", Compatibility.where(compatible_type: "ProductVariantRule", compatible_id: rules.select(:id)).count, true],
        ["vínculos con piezas de proveedor", r.supplier_links.count, true]]
    when Variant
      [["compatibilidades con productos y otras variantes", r.compatibilities.count + r.reverse_compatibilities.count, true],
        ["productos donde está disponible", r.compatible_product_ids.size, false],
        ["vínculos con piezas de proveedor", r.supplier_links.count, true]]
    when VariantType
      [["variantes que se eliminan junto con el tipo", r.variants.count, true],
        ["productos que usan este tipo en su código (perderán ese paso)", r.product_variant_rules.count, true],
        ["familias que lo usan", r.family_variant_rules.count, true]]
    when Family
      [["productos que quedarán sin familia (no se borran)", r.products.count, false],
        ["reglas de código de la familia", r.family_variant_rules.count, true]]
    when Provider
      items = r.supplier_items
      [["piezas de proveedor que se eliminan", items.count, true],
        ["vínculos de esas piezas con productos y variantes", SupplierLink.where(supplier_item_id: items.select(:id)).count, true],
        ["órdenes de compra (impiden eliminarlo)", r.purchase_orders.count, r.purchase_orders.count > 0]]
    when SupplierItem
      [["vínculos con productos y variantes", r.supplier_links.count, true]]
    end
  end
end
