class ProcurementPresenter
  def initialize(deliveries:, supply_rules:)
    @deliveries = deliveries
    @rules = supply_rules
    @line_details = {}
    precompute!
  end

  def details_for(order_number, product_name, supplier_item_id)
    @line_details[[order_number, product_name, supplier_item_id]] || {
      quantity: 0,
      cost: 0,
      unit: "-"
    }
  end

  def find_rule_in_cache(variant, base_product)
    @rules.find { |r| r.variant_id == variant.id && r.product_id == base_product&.id } ||
      @rules.find { |r| r.variant_id == variant.id && r.product_id.nil? } ||
      @rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id == base_product&.id } ||
      @rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id.nil? }
  end

  private

  def precompute!
    @deliveries.each do |delivery|
      delivery["items"].each do |item|
        decoding = ProductDecoder.decode(item["product_name"])
        next unless decoding.has_variants

        base_product = decoding.base_product
        qty_delivered = item["quantity_delivered"].to_f

        decoding.variants.each do |variant|
          rule = find_rule_in_cache(variant, base_product)
          next unless rule

          sid = rule.supplier_item_id

          qty_per_unit = ProcurementResolver.resolve_quantity(rule, base_product)
          calc_qty = qty_delivered * qty_per_unit
          cost = calc_qty * (rule.supplier_item&.default_cost || 0)

          @line_details[[delivery["order_number"], item["product_name"], sid]] = {
            quantity: calc_qty.round(4),
            cost: cost.round(2),
            unit: rule.supplier_item&.unit
          }
        end
      end
    end
  end
end
