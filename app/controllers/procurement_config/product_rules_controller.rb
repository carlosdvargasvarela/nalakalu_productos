module ProcurementConfig
  class ProductRulesController < BaseController
    def index
      @products = active_products.includes(:product_variant_rules)
      @supplier_items = active_supplier_items

      if params[:product_id].present?
        @product = Product.find(params[:product_id])
        load_product_data
      end
    end

    def save
      @product = Product.find(params[:id])
      errors = []

      ActiveRecord::Base.transaction do
        # ── 1. Reglas individuales ──────────────────────────────────────
        (params[:individual_rules] || {}).each do |key, data|
          variant_type_id, variant_id = key.split("_").map(&:to_i)

          if data[:supplier_item_id].blank?
            SupplyRule.find_by(
              product: @product,
              variant_type_id: variant_type_id,
              variant_id: variant_id
            )&.destroy
            next
          end

          rule = SupplyRule.find_or_initialize_by(
            product: @product,
            variant_type_id: variant_type_id,
            variant_id: variant_id
          )
          rule.assign_attributes(
            supplier_item_id: data[:supplier_item_id],
            quantity_needed: data[:quantity_needed].presence || 1.0,
            rule_type: "individual"
          )
          errors << rule.errors.full_messages unless rule.save
        end

        # ── 2. Reglas consolidadas ──────────────────────────────────────
        (params[:consolidated_rules] || {}).each do |variant_type_id_str, data|
          variant_type_id = variant_type_id_str.to_i

          if data[:supplier_item_id].blank?
            SupplyRule.where(
              product: @product,
              variant_type_id: variant_type_id,
              rule_type: "consolidated"
            ).destroy_all
            next
          end

          rule = SupplyRule.find_or_initialize_by(
            product: @product,
            variant_type_id: variant_type_id,
            rule_type: "consolidated"
          )
          rule.assign_attributes(
            supplier_item_id: data[:supplier_item_id],
            quantity_needed: data[:quantity_needed].presence || 1.0,
            variant_id: nil
          )
          errors << rule.errors.full_messages unless rule.save
        end

        raise ActiveRecord::Rollback if errors.any?
      end

      if errors.any?
        redirect_to procurement_config_product_rules_path(product_id: @product.id),
          alert: "Errores: #{errors.flatten.first(3).join(" | ")}"
      else
        redirect_to procurement_config_product_rules_path(product_id: @product.id),
          notice: "Reglas de '#{@product.name}' guardadas correctamente."
      end
    end

    private

    def load_product_data
      @product_variant_rules = @product.product_variant_rules
        .includes(:variant_type)
        .order(:position)

      # Reglas individuales existentes: key = "vtype_id_variant_id"
      @individual_rules = SupplyRule
        .where(product: @product, rule_type: "individual")
        .where.not(variant_id: nil)
        .index_by { |r| "#{r.variant_type_id}_#{r.variant_id}" }

      # Reglas consolidadas existentes: key = variant_type_id
      @consolidated_rules = SupplyRule
        .where(product: @product, rule_type: "consolidated")
        .index_by(&:variant_type_id)

      # Variantes globales (fallback) por variant_type
      @global_rules = SupplyRule
        .where(product_id: nil, rule_type: "individual")
        .where.not(variant_id: nil)
        .index_by(&:variant_id)
    end
  end
end
