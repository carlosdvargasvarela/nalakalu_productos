class ProcurementConsolidator
  def self.consolidate(requirements)
    requirements.group_by { |r| [r.supplier_item_id, r.specifications.to_s] }.map do |(item_id, _specs), reqs|
      first_req = reqs.first
      {
        supplier_item: first_req.supplier_item,
        specifications: first_req.specifications,
        total_quantity: reqs.sum(&:quantity),
        origin_orders: reqs.map(&:origin_order_number).uniq,
        requirement_ids: reqs.map(&:id),
        products: reqs.map(&:origin_product_name).uniq.join(", ")
      }
    end
  end
end
