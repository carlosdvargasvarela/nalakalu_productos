class ProcurementConsolidator
  def self.consolidate(requirements)
    requirements
      .group_by { |r| grouping_key(r) }
      .map do |(supplier_item_id, normalized_specs), reqs|
        first_req = reqs.first

        {
          supplier_item: first_req.supplier_item,
          specifications: normalized_specs,
          total_quantity: reqs.sum(&:quantity),
          requirement_ids: reqs.map(&:id),
          origin_orders: reqs.map(&:origin_order_number).uniq,
          products: reqs.map(&:origin_product_name).uniq.join(", "),
          origin_products: build_origin_products(reqs)
        }
      end
  end

  def self.grouping_key(requirement)
    [
      requirement.supplier_item_id,
      normalize_specs(requirement.specifications)
    ]
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

  def self.build_origin_products(reqs)
    reqs
      .map { |r|
        {
          product_name: r.origin_product_name || "—",
          quantity: r.quantity,
          order_number: r.origin_order_number
        }
      }
      .uniq { |op| [op[:product_name], op[:order_number]] }
      .sort_by { |op| op[:order_number].to_s }
  end
end
