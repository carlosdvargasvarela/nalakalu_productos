class ProcurementConsolidator
  def self.consolidate(requirements)
    requirements.map do |req|
      {
        supplier_item: req.supplier_item,
        specifications: normalize_specs(req.specifications),
        total_quantity: req.quantity,
        requirement_ids: [req.id],
        origin_orders: [req.origin_order_number],
        products: req.origin_product_name,
        origin_products: [{
          product_name: req.origin_product_name || "—",
          quantity: req.quantity,
          order_number: req.origin_order_number
        }]
      }
    end
  end

  # Unifica symbol keys y string keys → siempre string keys para comparación
  def self.normalize_specs(specs)
    return [] if specs.blank?

    Array(specs)
      .map do |s|
        {
          "label" => (s[:label] || s["label"]).to_s,
          "value" => (s[:value] || s["value"]).to_s
        }
      end
      .sort_by { |s| s["label"] }
  end
end
