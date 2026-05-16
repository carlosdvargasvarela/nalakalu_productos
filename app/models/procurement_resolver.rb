class ProcurementResolver
  CACHE_KEY_RULES = "procurement:supply_rules:v1"

  def self.resolve_delivery(delivery)
    accumulation = Hash.new do |h, k|
      h[k] = {qty: 0.0, specs: [], products: [], rule_id: nil, counted_items: Set.new}
    end

    delivery["items"].each do |item|
      decoding = ProductDecoder.decode(item["product_name"])
      next unless decoding.has_variants

      base_product = decoding.base_product
      qty_delivered = item["quantity_delivered"].to_f
      item_key = item["id"] || item["product_name"]

      variants_by_strategy = group_variants_by_strategy(decoding.variants, base_product)

      # ── INDIVIDUAL ──────────────────────────────────────────────────────
      variants_by_strategy[:individual].each do |variant|
        rule = find_individual_rule(variant, base_product)
        next unless rule&.supplier_item_id
        next unless rule.supplier_item&.active?

        sid = rule.supplier_item_id
        qty = resolve_quantity(rule, base_product)

        accumulation[sid][:qty] += qty_delivered * qty
        accumulation[sid][:products] << item["product_name"]
        accumulation[sid][:rule_id] ||= rule.id

        specs = build_specifications(rule.supplier_item, [variant], base_product)
        accumulation[sid][:specs] = merge_specs(accumulation[sid][:specs], specs)
      end

      # ── CONSOLIDADO ─────────────────────────────────────────────────────
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

        specs = build_specifications(rule.supplier_item, group[:variants], base_product)
        accumulation[sid][:specs] = merge_specs(accumulation[sid][:specs], specs)
      end
    end

    persist_accumulation(delivery, accumulation)
  end

  # ── QUANTITY ─────────────────────────────────────────────────────────────

  def self.resolve_quantity(rule, base_product)
    if base_product && rule.supply_rule_quantities.any?
      specific = rule.supply_rule_quantities.find { |q| q.product_id == base_product.id }
      return specific.quantity_needed.to_f if specific
    end
    rule.quantity_needed.to_f
  end

  # ── PERSIST ──────────────────────────────────────────────────────────────

  def self.persist_accumulation(delivery, accumulation)
    results = []

    accumulation.each do |sid, data|
      req = ProcurementRequirement.find_or_initialize_by(
        origin_order_number: delivery["order_number"],
        supplier_item_id: sid
      )

      next if req.persisted? && req.status.in?(%w[ordered received])

      req.assign_attributes(
        origin_delivery_id: delivery["id"].to_s,
        origin_product_name: data[:products].uniq.first,
        origin_products: (Array(req.origin_products) | data[:products]).uniq,
        quantity: data[:qty].round(4),
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

  # ── GROUPING ─────────────────────────────────────────────────────────────

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

  # ── RULE RESOLUTION ──────────────────────────────────────────────────────

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

  # ── SPECS ─────────────────────────────────────────────────────────────────

  def self.build_specifications(supplier_item, variants, base_product = nil)
    return [] if supplier_item.blank?

    allowed_labels = supplier_item_specs_cache(supplier_item.id)
    return [] if allowed_labels.empty?

    incoming_specs = variants.filter_map do |v|
      label = resolve_variant_label(v, base_product)
      next unless label.present?
      {label: label, value: v.display_name.presence || v.name}
    end

    filtered = incoming_specs.select { |spec| allowed_labels.include?(spec[:label]) }
    validate_missing_specs(supplier_item, filtered, allowed_labels)
    filtered
  end

  def self.resolve_variant_label(variant, base_product)
    if base_product.present?
      rule = base_product.product_variant_rules
        .find { |pvr| pvr.variant_type_id == variant.variant_type_id }
      return rule.label if rule&.label.present?
    end
    variant.variant_type.name
  end

  def self.validate_missing_specs(supplier_item, specs, expected_labels = nil)
    expected = expected_labels || supplier_item_specs_cache(supplier_item.id)
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
    normalized = existing.map { |s|
      {label: (s[:label] || s["label"]).to_s, value: (s[:value] || s["value"]).to_s}
    }
    (normalized + incoming).uniq { |s| "#{s[:label]}-#{s[:value]}" }
  end

  # ── CACHE (SOLO Rails.cache — sin Thread.current) ────────────────────────

  def self.all_supply_rules
    Rails.cache.fetch(CACHE_KEY_RULES, expires_in: 10.minutes) do
      SupplyRule
        .joins(:supplier_item)
        .includes(:variant_type, :variant, :supplier_item, :supply_rule_quantities)
        .where(supplier_items: {active: true})
        .to_a
    end
  end

  def self.supplier_item_specs_cache(supplier_item_id)
    Rails.cache.fetch("procurement:specs:#{supplier_item_id}", expires_in: 10.minutes) do
      SupplierItemProperty
        .where(supplier_item_id: supplier_item_id, spec_type: "spec")
        .pluck(:label)
    end
  end

  def self.clear_cache!
    Rails.cache.delete(CACHE_KEY_RULES)
    ProductDecoder.clear_cache!
  end

end
