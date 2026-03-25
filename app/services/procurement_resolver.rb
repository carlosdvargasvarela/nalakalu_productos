class ProcurementResolver
  def self.resolve_delivery(delivery_data)
    new(delivery_data).resolve
  end

  def initialize(delivery_data)
    @delivery = delivery_data
    @order_number = @delivery["order_number"]
    @delivery_id = @delivery["id"]
  end

  def resolve
    requirements = []

    @delivery["items"].each do |item|
      decoding = ProductDecoder.decode(item["product_name"])
      next unless decoding[:base_product] && decoding[:has_variants]

      product = decoding[:base_product]
      variants = decoding[:variants]
      qty_delivered = item["quantity_delivered"].to_f

      grouped_variants = variants.group_by { |v| v.variant_type.procurement_strategy }

      if grouped_variants["individual"]
        grouped_variants["individual"].each do |variant|
          req = create_individual_requirement(product, variant, qty_delivered, item["product_name"])
          requirements << req if req
        end
      end

      if grouped_variants["consolidated"]
        grouped_variants["consolidated"].group_by(&:variant_type_id).each do |type_id, type_variants|
          req = create_consolidated_requirement(product, type_id, type_variants, qty_delivered, item["product_name"])
          requirements << req if req
        end
      end
    end

    requirements.compact
  end

  private

  def create_individual_requirement(product, variant, qty, full_name)
    rule = SupplyRule.find_by(product: product, variant: variant) ||
      SupplyRule.find_by(product: nil, variant: variant)

    return nil unless rule

    total_qty = qty * rule.quantity_needed

    ProcurementRequirement.find_or_create_by!(
      supplier_item: rule.supplier_item,
      origin_order_number: @order_number,
      specifications: {}
    ) do |pr|
      pr.origin_delivery_id = @delivery_id
      pr.origin_product_name = full_name
      pr.quantity = total_qty
      pr.status = "pending"
    end
  end

  def create_consolidated_requirement(product, type_id, type_variants, qty, full_name)
    # Variable local para no pisar la variable `rule` del bloque exterior
    supply_rule = SupplyRule.find_by(product: product, variant_type_id: type_id, rule_type: "consolidated") ||
      SupplyRule.find_by(product: nil, variant_type_id: type_id, rule_type: "consolidated")

    return nil unless supply_rule

    # Obtener las reglas del producto ordenadas por posición para mapear N1, N2, N3
    product_rules = product.product_variant_rules
      .where(variant_type_id: type_id)
      .order(:position)

    specs = {}
    type_variants.each_with_index do |v, index|
      pr_rule = product_rules[index]
      key = pr_rule&.label.presence || "N#{index + 1}"
      specs[key] = v.name
    end

    total_qty = qty * supply_rule.quantity_needed

    ProcurementRequirement.find_or_create_by!(
      supplier_item: supply_rule.supplier_item,
      origin_order_number: @order_number,
      specifications: specs
    ) do |pr|
      pr.origin_delivery_id = @delivery_id
      pr.origin_product_name = full_name
      pr.quantity = total_qty
      pr.status = "pending"
    end
  end
end
