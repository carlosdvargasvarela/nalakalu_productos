# app/models/procurement_resolver.rb
class ProcurementResolver
  def self.resolve_delivery(delivery)
    requirements = []

    delivery["items"].each do |item|
      decoding = ProductDecoder.decode(item["product_name"])
      next unless decoding[:has_variants]

      variants_by_strategy = group_variants_by_strategy(decoding[:variants])

      variants_by_strategy[:individual].each do |variant|
        req = create_requirement(delivery, item, variant)
        requirements << req if req.present?
      end

      variants_by_strategy[:consolidated].each do |_supplier_item_id, variants|
        req = create_consolidated_requirement(delivery, item, variants)
        requirements << req if req.present?
      end
    end

    requirements.compact
  end

  private

  def self.group_variants_by_strategy(variants)
    groups = {individual: [], consolidated: {}}

    variants.each do |v|
      variant_type = v.variant_type
      next unless variant_type

      strategy = variant_type.procurement_strategy.to_s

      if strategy == "consolidated"
        rule = SupplyRule.find_by(variant_id: v.id)
        if rule
          groups[:consolidated][rule.supplier_item_id] ||= []
          groups[:consolidated][rule.supplier_item_id] << v
        end
      else
        groups[:individual] << v
      end
    end

    groups
  end

  def self.create_requirement(delivery, item, variant)
    rule = SupplyRule.find_by(variant_id: variant.id)
    return nil unless rule&.supplier_item.present?

    ProcurementRequirement.find_or_create_by!(
      origin_order_number: delivery["order_number"],
      supplier_item_id: rule.supplier_item_id
    ) do |r|
      r.origin_delivery_id = delivery["id"].to_s
      r.origin_product_name = item["product_name"]
      r.quantity = item["quantity_delivered"].to_f * rule.quantity_needed.to_f
      r.status = "pending"
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[ProcurementResolver] Individual: #{e.message}"
    nil
  end

  def self.create_consolidated_requirement(delivery, item, variants)
    return nil if variants.blank?

    rule = SupplyRule.find_by(variant_id: variants.first.id)
    return nil unless rule&.supplier_item.present?

    specs = variants.each_with_object({}) do |v, hash|
      hash[v.variant_type.name] = v.name
    end

    # find_or_create_by solo por los campos indexados en BD
    # Las specs se actualizan si el registro ya existe (re-importación)
    req = ProcurementRequirement.find_or_initialize_by(
      origin_order_number: delivery["order_number"],
      supplier_item_id: rule.supplier_item_id
    )

    if req.new_record?
      req.assign_attributes(
        origin_delivery_id: delivery["id"].to_s,
        origin_product_name: item["product_name"],
        quantity: item["quantity_delivered"].to_f * rule.quantity_needed.to_f,
        specifications: specs,
        status: "pending"
      )
      req.save!
    end

    req
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[ProcurementResolver] Consolidated: #{e.message}"
    nil
  end
end
