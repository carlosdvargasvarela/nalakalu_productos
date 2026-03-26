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

  private

  def precompute!
    @deliveries.each do |delivery|
      delivery["items"].each do |item|
        # 🔥 Usamos el decoder (que ya tiene el cache cargado por el controller)
        decoding = ProductDecoder.decode(item["product_name"])
        next unless decoding.has_variants

        base_product = decoding.base_product
        qty_delivered = item["quantity_delivered"].to_f

        decoding.variants.each do |variant|
          # 🔥 Usamos la misma lógica de prioridad que el Resolver
          rule = find_rule_in_cache(variant, base_product)
          next unless rule

          sid = rule.supplier_item_id
          calc_qty = qty_delivered * rule.quantity_needed.to_f
          cost = calc_qty * (rule.supplier_item.default_cost || 0)

          @line_details[[delivery["order_number"], item["product_name"], sid]] = {
            quantity: calc_qty,
            cost: cost,
            unit: rule.supplier_item.unit
          }
        end
      end
    end
  end

  def find_rule_in_cache(variant, base_product)
    # Prioridad 1: Variante + Producto
    @rules.find { |r| r.variant_id == variant.id && r.product_id == base_product&.id } ||
      # Prioridad 2: Variante sola
      @rules.find { |r| r.variant_id == variant.id && r.product_id.nil? } ||
      # Prioridad 3: Tipo de Variante + Producto
      @rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id == base_product&.id } ||
      # Prioridad 4: Tipo de Variante solo
      @rules.find { |r| r.variant_id.nil? && r.variant_type_id == variant.variant_type_id && r.product_id.nil? }
  end
end
