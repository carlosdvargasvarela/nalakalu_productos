class ProcurementResolver
  def self.resolve_delivery(delivery)
    clear_cache!
    accumulation = Hash.new { |h, k| h[k] = {qty: 0.0, specs: {}, products: [], rule_id: nil} }

    delivery["items"].each do |item|
      decoding = ProductDecoder.decode(item["product_name"])
      next unless decoding.has_variants

      base_product = decoding.base_product
      qty_delivered = item["quantity_delivered"].to_f

      variants_by_strategy = group_variants_by_strategy(decoding.variants, base_product)

      variants_by_strategy[:individual].each do |variant|
        rule = find_rule(variant, base_product)
        next unless rule&.supplier_item_id

        sid = rule.supplier_item_id
        accumulation[sid][:qty] += qty_delivered * rule.quantity_needed.to_f
        accumulation[sid][:products] << item["product_name"]
        accumulation[sid][:rule_id] ||= rule.id
      end

      variants_by_strategy[:consolidated].each do |sid, group|
        rule = group[:rule]
        accumulation[sid][:qty] += qty_delivered * rule.quantity_needed.to_f
        accumulation[sid][:products] << item["product_name"]
        accumulation[sid][:rule_id] ||= rule.id

        group[:variants].each do |v|
          key = v.variant_type.name
          accumulation[sid][:specs][key] = v.display_name.presence || v.name
        end
      end
    end

    persist_accumulation(delivery, accumulation)
  end

  private

  def self.persist_accumulation(delivery, accumulation)
    results = []

    accumulation.each do |sid, data|
      req = ProcurementRequirement.find_or_initialize_by(
        origin_order_number: delivery["order_number"],
        supplier_item_id: sid
      )

      next if req.persisted? && req.ordered?

      req.assign_attributes(
        origin_delivery_id: delivery["id"].to_s,
        origin_product_name: data[:products].uniq.first,
        origin_products: data[:products].uniq,
        quantity: data[:qty],
        specifications: data[:specs],
        supply_rule_id: data[:rule_id],
        status: "pending"
      )

      if req.save
        results << req
      else
        Rails.logger.error "[ProcurementResolver] Error en sid=#{sid}: #{req.errors.full_messages.join(", ")}"
      end
    end

    results
  end

  def self.group_variants_by_strategy(variants, base_product)
    groups = {individual: [], consolidated: {}}

    variants.each do |v|
      variant_type = v.variant_type
      next unless variant_type

      rule = find_rule(v, base_product)
      next unless rule.present?

      if variant_type.consolidated?
        sid = rule.supplier_item_id
        groups[:consolidated][sid] ||= {rule: rule, variants: []}
        groups[:consolidated][sid][:variants] << v
      else
        groups[:individual] << v
      end
    end

    groups
  end

  def self.find_rule(variant, base_product)
    rules = all_supply_rules

    rules.find { |r| r.variant_id == variant.id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_id == variant.id && r.product_id.nil? } ||
      rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id.nil? }
  end

  def self.all_supply_rules
    Thread.current[:supply_rules_cache] ||= SupplyRule
      .includes(:variant_type, :variant, :supplier_item, :supply_rule_quantities)
      .to_a
  end

  def self.clear_cache!
    Thread.current[:supply_rules_cache] = nil
  end
end
