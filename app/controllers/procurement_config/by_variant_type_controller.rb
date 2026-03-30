module ProcurementConfig
  class ByVariantTypeController < BaseController
    def index
      @variant_types = VariantType.where(active: true, procurement_strategy: "individual")
        .order(:name)
      @supplier_items = active_supplier_items

      if params[:variant_type_id].present?
        @variant_type = VariantType.find(params[:variant_type_id])
        @variants = @variant_type.variants.where(active: true).order(:name)

        @existing_rules = SupplyRule
          .where(variant_type: @variant_type, product_id: nil)
          .where.not(variant_id: nil)
          .index_by(&:variant_id)
      end
    end

    def save
      variant_type = VariantType.find(params[:variant_type_id])
      rules_params = params[:rules] || {}
      errors = []

      ActiveRecord::Base.transaction do
        rules_params.each do |variant_id_str, data|
          variant_id = variant_id_str.to_i

          if data[:supplier_item_id].blank?
            SupplyRule.find_by(
              variant_type: variant_type,
              variant_id: variant_id,
              product_id: nil
            )&.destroy
            next
          end

          rule = SupplyRule.find_or_initialize_by(
            variant_type: variant_type,
            variant_id: variant_id,
            product_id: nil
          )

          rule.assign_attributes(
            supplier_item_id: data[:supplier_item_id],
            quantity_needed: data[:quantity_needed].presence || 1.0,
            rule_type: "individual"
          )

          errors << rule.errors.full_messages unless rule.save
        end

        raise ActiveRecord::Rollback if errors.any?
      end

      if errors.any?
        redirect_to procurement_config_by_variant_type_path(variant_type_id: variant_type.id),
          alert: "Errores: #{errors.flatten.first(3).join(" | ")}"
      else
        redirect_to procurement_config_by_variant_type_path(variant_type_id: variant_type.id),
          notice: "Reglas de '#{variant_type.name}' guardadas correctamente."
      end
    end

    def quantities
      @rule = SupplyRule.includes(:variant, :variant_type, :supplier_item)
        .find(params[:supply_rule_id])
      @products = active_products
      @quantities = @rule.supply_rule_quantities.index_by(&:product_id)
    end

    def save_quantities
      @rule = SupplyRule.find(params[:supply_rule_id])
      quantities_params = params[:quantities] || {}
      errors = []

      ActiveRecord::Base.transaction do
        quantities_params.each do |product_id_str, data|
          product_id = product_id_str.to_i

          if data[:quantity_needed].blank? || data[:quantity_needed].to_f <= 0
            @rule.supply_rule_quantities.find_by(product_id: product_id)&.destroy
            next
          end

          qty = @rule.supply_rule_quantities.find_or_initialize_by(product_id: product_id)
          qty.quantity_needed = data[:quantity_needed]
          errors << qty.errors.full_messages unless qty.save
        end

        raise ActiveRecord::Rollback if errors.any?
      end

      if errors.any?
        redirect_to procurement_config_quantities_by_variant_type_path(@rule),
          alert: "Errores: #{errors.flatten.first(3).join(" | ")}"
      else
        redirect_to procurement_config_by_variant_type_path(
          variant_type_id: @rule.variant_type_id
        ), notice: "Cantidades por producto guardadas."
      end
    end
  end
end
