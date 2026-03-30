module ProcurementConfig
  class ByProductController < BaseController
    def index
      @products = active_products
      @supplier_items = active_supplier_items

      if params[:product_id].present?
        @product = Product.find(params[:product_id])
        @variant_types = @product.variant_types.includes(:variants).order(:name)

        @existing_rules = SupplyRule
          .where(product: @product)
          .index_by { |r| "#{r.variant_type_id}_#{r.variant_id}" }
      end
    end

    def save
      product = Product.find(params[:product_id])
      rules_params = params[:rules] || {}
      errors = []

      ActiveRecord::Base.transaction do
        rules_params.each do |key, data|
          variant_type_id, variant_id = key.split("_").map { |x| x.presence&.to_i }

          if data[:supplier_item_id].blank?
            SupplyRule.find_by(
              product: product,
              variant_type_id: variant_type_id,
              variant_id: variant_id
            )&.destroy
            next
          end

          rule = SupplyRule.find_or_initialize_by(
            product: product,
            variant_type_id: variant_type_id,
            variant_id: variant_id.presence
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
        redirect_to procurement_config_by_product_path(product_id: product.id),
          alert: "Errores: #{errors.flatten.first(3).join(" | ")}"
      else
        redirect_to procurement_config_by_product_path(product_id: product.id),
          notice: "Reglas de '#{product.name}' guardadas correctamente."
      end
    end
  end
end
