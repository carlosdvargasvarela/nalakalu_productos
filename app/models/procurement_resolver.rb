class ProcurementResolver
  def self.resolve_delivery(delivery)
    clear_cache!

    accumulation = Hash.new do |h, k|
      h[k] = {
        qty: 0.0,
        specs: [],
        products: [],
        rule_id: nil,
        counted_items: Set.new
      }
    end

    delivery["items"].each do |item|
      decoding = ProductDecoder.decode(item["product_name"])
      next unless decoding.has_variants

      base_product = decoding.base_product
      qty_delivered = item["quantity_delivered"].to_f
      item_key = item["id"] || item["product_name"]

      variants_by_strategy = group_variants_by_strategy(decoding.variants, base_product)

      # ─────────────────────────────────────────────
      # INDIVIDUAL
      # ─────────────────────────────────────────────
      variants_by_strategy[:individual].each do |variant|
        rule = find_individual_rule(variant, base_product)
        next unless rule&.supplier_item_id
        next unless rule.supplier_item&.active?

        sid = rule.supplier_item_id
        qty = resolve_quantity(rule, base_product)

        accumulation[sid][:qty] += qty_delivered * qty
        accumulation[sid][:products] << item["product_name"]
        accumulation[sid][:rule_id] ||= rule.id

        # ✅ NUEVO: specs
        specs = build_specifications(rule.supplier_item, [variant], base_product)
        accumulation[sid][:specs] = merge_specs(accumulation[sid][:specs], specs)
      end

      # ─────────────────────────────────────────────
      # CONSOLIDADO
      # ─────────────────────────────────────────────
      variants_by_strategy[:consolidated].each do |sid, group|
        rule = group[:rule]
        next unless rule.supplier_item&.active?

        unless accumulation[sid][:counted_items].include?(item_key)
          qty = resolve_quantity(rule, base_product)
          accumulation[sid][:qty] += qty_delivered * qty
          accumulation[sid][:counted_items] << item_key
        end

        accumulation[sid][:products] << item["product_name"]
        accumulation[sid][:rule_id] ||= rule.id

        # ✅ NUEVO: specs correctas
        specs = build_specifications(rule.supplier_item, group[:variants], base_product)
        accumulation[sid][:specs] = merge_specs(accumulation[sid][:specs], specs)
      end
    end

    persist_accumulation(delivery, accumulation)
  end

  # ─────────────────────────────────────────────
  # QUANTITY
  # ─────────────────────────────────────────────
  def self.resolve_quantity(rule, base_product)
    if base_product && rule.supply_rule_quantities.any?
      specific = rule.supply_rule_quantities.find { |q| q.product_id == base_product.id }
      return specific.quantity_needed.to_f if specific
    end
    rule.quantity_needed.to_f
  end

  # ─────────────────────────────────────────────
  # PERSIST
  # ─────────────────────────────────────────────
  def self.persist_accumulation(delivery, accumulation)
    results = []

    accumulation.each do |sid, data|
      req = ProcurementRequirement.find_or_initialize_by(
        origin_order_number: delivery["order_number"],
        supplier_item_id: sid
      )

      next if req.persisted? && req.status.in?(%w[ordered confirmed received])

      new_qty = data[:qty].round(4)

      req.assign_attributes(
        origin_delivery_id: delivery["id"].to_s,
        origin_product_name: data[:products].uniq.first,
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

  # ─────────────────────────────────────────────
  # GROUPING
  # ─────────────────────────────────────────────
  def self.group_variants_by_strategy(variants, base_product)
    groups = {individual: [], consolidated: {}}

    variants.each do |v|
      variant_type = v.variant_type
      next unless variant_type

      if variant_type.consolidated?
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

  # ─────────────────────────────────────────────
  # RULE RESOLUTION
  # ─────────────────────────────────────────────
  def self.find_individual_rule(variant, base_product)
    rules = all_supply_rules.select { |r| r.rule_type == "individual" }

    rules.find { |r| r.variant_id == variant.id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_id == variant.id && r.product_id.nil? } ||
      rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id.nil? }
  end

  def self.find_consolidated_rule(variant_type, base_product)
    rules = all_supply_rules.select { |r| r.rule_type == "consolidated" }

    rules.find { |r| r.variant_type_id == variant_type.id && r.product_id == base_product&.id } ||
      rules.find { |r| r.variant_type_id == variant_type.id && r.product_id.nil? }
  end

  # ─────────────────────────────────────────────
  # SPECS (CORE NUEVO)
  # ─────────────────────────────────────────────
  def self.build_specifications(supplier_item, variants, base_product = nil)
    return [] if supplier_item.blank?

    # ✅ labels definidos en SupplierItem (ej: F1, F2, F3)
    allowed_labels = supplier_item.supplier_item_properties
      .specs
      .pluck(:label)

    return [] if allowed_labels.empty?

    # ✅ construir specs desde variantes usando el label del ProductVariantRule
    incoming_specs = variants.map do |v|
      label = resolve_variant_label(v, base_product)
      next unless label.present?

      {
        label: label,
        value: v.display_name.presence || v.name
      }
    end.compact

    # ✅ filtrar solo los labels que el supplier_item entiende
    filtered = incoming_specs.select do |spec|
      allowed_labels.include?(spec[:label])
    end

    validate_missing_specs(supplier_item, filtered)

    filtered
  end

  # ✅ Resuelve el label correcto para una variante
  # Prioridad: ProductVariantRule.label → variant_type.name
  def self.resolve_variant_label(variant, base_product)
    if base_product.present?
      rule = base_product.product_variant_rules
        .find { |pvr| pvr.variant_type_id == variant.variant_type_id }

      return rule.label if rule&.label.present?
    end

    # fallback: nombre del tipo
    variant.variant_type.name
  end

  # ✅ Warning si faltan specs esperadas
  def self.validate_missing_specs(supplier_item, specs)
    expected = supplier_item.supplier_item_properties.specs.pluck(:label)
    received = specs.map { |s| s[:label] }
    missing = expected - received

    if missing.any?
      Rails.logger.warn(
        "[ProcurementResolver] SupplierItem #{supplier_item.id} " \
        "(#{supplier_item.name}) esperaba: #{expected.join(", ")} " \
        "— faltaron: #{missing.join(", ")}"
      )
    end
  end

  def self.merge_specs(existing, incoming)
    normalized_existing = existing.map { |s|
      {label: (s[:label] || s["label"]).to_s, value: (s[:value] || s["value"]).to_s}
    }
    (normalized_existing + incoming).uniq { |s| "#{s[:label]}-#{s[:value]}" }
  end

  # ─────────────────────────────────────────────
  # CACHE
  # ─────────────────────────────────────────────
  def self.all_supply_rules
    Thread.current[:supply_rules_cache] ||= SupplyRule
      .includes(:variant_type, :variant, :supplier_item, :supply_rule_quantities)
      .where(supplier_items: {active: true})
      .to_a
  end

  def self.clear_cache!
    Thread.current[:supply_rules_cache] = nil
    ProductDecoder.clear_cache!
  end
end
