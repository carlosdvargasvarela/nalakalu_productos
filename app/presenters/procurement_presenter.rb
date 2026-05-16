class ProcurementPresenter
  def initialize(deliveries:, supply_rules:)
    @deliveries = deliveries
    @rules = supply_rules
    @line_details = {}
    @decode_cache = {}
    precompute!
  end

  # ── API pública ──────────────────────────────────────────────────────────

  def decoded(product_name)
    decode_cached(product_name)
  end

  def details_for(order_number, product_name, supplier_item_id)
    @line_details[[order_number, product_name, supplier_item_id]] || {
      quantity: 0,
      cost: 0,
      unit: "-"
    }
  end

  # Resuelve la regla para una variante (individual o consolidada)
  def find_rule_in_cache(variant, base_product)
    if variant.variant_type&.consolidated?
      find_consolidated_rule(variant.variant_type, base_product)
    else
      find_individual_rule(variant, base_product)
    end
  end

  private

  def precompute!
    @deliveries.each do |delivery|
      delivery["items"].each do |item|
        decoding = decode_cached(item["product_name"])
        next unless decoding.has_variants

        base_product = decoding.base_product
        qty_delivered = item["quantity_delivered"].to_f
        order_number = delivery["order_number"]
        product_name = item["product_name"]

        groups = group_variants_by_strategy(decoding.variants, base_product)

        groups[:individual].each do |variant|
          rule = find_individual_rule(variant, base_product)
          next unless rule
          record_line_detail(order_number, product_name, rule, qty_delivered, base_product)
        end

        groups[:consolidated].each do |_sid, group|
          record_line_detail(order_number, product_name, group[:rule], qty_delivered, base_product)
        end
      end
    end
  end

  def group_variants_by_strategy(variants, base_product)
    groups = {individual: [], consolidated: {}}

    variants.each do |v|
      vt = v.variant_type
      next unless vt

      if vt.consolidated?
        rule = find_consolidated_rule(vt, base_product)
        next unless rule

        sid = rule.supplier_item_id
        groups[:consolidated][sid] ||= {rule: rule, variants: []}
        groups[:consolidated][sid][:variants] << v
      else
        groups[:individual] << v
      end
    end

    groups
  end

  def find_individual_rule(variant, base_product)
    rules = @rules.select { |r| r.rule_type == "individual" }

    rules.find { |r| r.variant_id == variant.id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_id == variant.id && r.product_id.nil? } ||
      rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id.nil? }
  end

  def find_consolidated_rule(variant_type, base_product)
    rules = @rules.select { |r| r.rule_type == "consolidated" }

    rules.find { |r| r.variant_type_id == variant_type.id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_type_id == variant_type.id && r.product_id.nil? }
  end

  def record_line_detail(order_number, product_name, rule, qty_delivered, base_product)
    sid = rule.supplier_item_id
    qty_per_unit = ProcurementResolver.resolve_quantity(rule, base_product)
    calc_qty = qty_delivered * qty_per_unit
    cost = calc_qty * (rule.supplier_item&.default_cost || 0)

    @line_details[[order_number, product_name, sid]] = {
      quantity: calc_qty.round(4),
      cost: cost.round(2),
      unit: rule.supplier_item&.unit
    }
  end

  def decode_cached(product_name)
    @decode_cache[product_name] ||= ProductDecoder.decode(product_name)
  end
end
