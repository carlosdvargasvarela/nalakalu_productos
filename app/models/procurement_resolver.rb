# app/services/procurement_resolver.rb

class ProcurementResolver
  def self.resolve_delivery(delivery)
    clear_cache!
    accumulation = Hash.new do |h, k|
      h[k] = {qty: 0.0, specs: {}, products: [], rule_id: nil, counted_items: Set.new}
    end

    delivery["items"].each do |item|
      decoding = ProductDecoder.decode(item["product_name"])
      next unless decoding.has_variants

      base_product = decoding.base_product
      qty_delivered = item["quantity_delivered"].to_f
      item_key = item["id"] || item["product_name"]

      variants_by_strategy = group_variants_by_strategy(decoding.variants, base_product)

      # --- INDIVIDUAL ---
      variants_by_strategy[:individual].each do |variant|
        rule = find_individual_rule(variant, base_product)
        next unless rule&.supplier_item_id
        # 🔒 Solo si el supplier_item está activo
        next unless rule.supplier_item&.active?

        sid = rule.supplier_item_id
        qty = resolve_quantity(rule, base_product)

        accumulation[sid][:qty] += qty_delivered * qty
        accumulation[sid][:products] << item["product_name"]
        accumulation[sid][:rule_id] ||= rule.id
      end

      # --- CONSOLIDADO ---
      variants_by_strategy[:consolidated].each do |sid, group|
        rule = group[:rule]
        next unless rule.supplier_item&.active? # 🔒

        unless accumulation[sid][:counted_items].include?(item_key)
          qty = resolve_quantity(rule, base_product)
          accumulation[sid][:qty] += qty_delivered * qty
          accumulation[sid][:counted_items] << item_key
        end

        accumulation[sid][:products] << item["product_name"]
        accumulation[sid][:rule_id] ||= rule.id

        group[:variants].each do |v|
          key = v.variant_type.name
          accumulation[sid][:specs][key] ||= v.display_name.presence || v.name
        end
      end
    end

    persist_accumulation(delivery, accumulation)
  end

  def self.resolve_quantity(rule, base_product)
    if base_product && rule.supply_rule_quantities.any?
      specific = rule.supply_rule_quantities.find { |q| q.product_id == base_product.id }
      return specific.quantity_needed.to_f if specific
    end
    rule.quantity_needed.to_f
  end

  def self.persist_accumulation(delivery, accumulation)
    results = []

    accumulation.each do |sid, data|
      req = ProcurementRequirement.find_or_initialize_by(
        origin_order_number: delivery["order_number"],
        supplier_item_id: sid
      )

      next if req.persisted? && req.status.in?(%w[ordered confirmed received])

      # Solo actualizar quantity si es nuevo o si cambió significativamente
      new_qty = data[:qty].round(4)
      qty_changed = !req.persisted? || (req.quantity.to_f - new_qty).abs > 0.001

      req.assign_attributes(
        origin_delivery_id: delivery["id"].to_s,
        origin_product_name: data[:products].uniq.first,
        # Merge con origin_products existentes en lugar de sobreescribir
        origin_products: (Array(req.origin_products) | data[:products]).uniq,
        quantity: new_qty,
        specifications: data[:specs],
        supply_rule_id: data[:rule_id],
        status: req.persisted? ? req.status : "pending"
      )

      if req.save
        results << req
      else
        Rails.logger.error "[ProcurementResolver] Error sid=#{sid}: #{req.errors.full_messages.join(", ")}"
      end
    end

    results
  end

  def self.group_variants_by_strategy(variants, base_product)
    groups = {individual: [], consolidated: {}}

    variants.each do |v|
      variant_type = v.variant_type
      next unless variant_type

      if variant_type.consolidated?
        # Para consolidados buscamos la regla por tipo+producto, NO por variant_id
        rule = find_consolidated_rule(variant_type, base_product)
        next unless rule.present?

        sid = rule.supplier_item_id
        groups[:consolidated][sid] ||= {rule: rule, variants: []}
        groups[:consolidated][sid][:variants] << v
      else
        groups[:individual] << v
      end
    end

    groups
  end

  # Busca reglas individuales (por variant_id)
  def self.find_individual_rule(variant, base_product)
    rules = all_supply_rules.select { |r| r.rule_type == "individual" }

    rules.find { |r| r.variant_id == variant.id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_id == variant.id && r.product_id.nil? } ||
      rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id.nil? }
  end

  # Busca reglas consolidadas (por variant_type + product, sin variant_id)
  def self.find_consolidated_rule(variant_type, base_product)
    rules = all_supply_rules.select { |r| r.rule_type == "consolidated" }

    rules.find { |r| r.variant_type_id == variant_type.id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_type_id == variant_type.id && r.product_id.nil? }
  end

  def self.all_supply_rules
    Thread.current[:supply_rules_cache] ||= SupplyRule
      .includes(:variant_type, :variant, :supplier_item, :supply_rule_quantities)
      .where(supplier_items: {active: true}) # Solo reglas con item activo
      .to_a
  end

  def self.clear_cache!
    Thread.current[:supply_rules_cache] = nil
    ProductDecoder.clear_cache!
  end
end
