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
          origin_orders: reqs.map(&:origin_order_number).uniq,
          requirement_ids: reqs.map(&:id),
          products: reqs.map(&:origin_product_name).uniq.join(", ")
        }
      end
  end

  # ─────────────────────────────────────────────
  # KEY DE AGRUPACIÓN (CLAVE)
  # ─────────────────────────────────────────────
  def self.grouping_key(requirement)
    [
      requirement.supplier_item_id,
      normalize_specs(requirement.specifications)
    ]
  end

  # ─────────────────────────────────────────────
  # NORMALIZACIÓN DE SPECS
  # ─────────────────────────────────────────────
  def self.normalize_specs(specs)
    return [] if specs.blank?

    specs
      .map do |s|
        {
          "label" => s["label"] || s[:label],
          "value" => s["value"] || s[:value]
        }
      end
      .sort_by { |s| [s["label"].to_s, s["value"].to_s] }
  end
end
