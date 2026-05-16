module ProcurementConfig
  class ConsolidatedController < BaseController
    def index
      @products = active_products
      @variant_types = VariantType.where(active: true, procurement_strategy: "consolidated")
        .order(:name)
      @supplier_items = active_supplier_items

      variant_type_id = params[:variant_type_id].presence
      product_id = params[:product_id].presence

      if variant_type_id.present?
        @variant_type = VariantType.find(variant_type_id)
        @variants = @variant_type.variants.where(active: true).order(:name)
        @product = Product.find(product_id) if product_id

        @rule = SupplyRule.find_by(
          product: @product,
          variant_type: @variant_type,
          rule_type: "consolidated"
        )

        @properties = Property.where(active: true).includes(:property_values).order(:name)
      end
    end

    def save
      variant_type = VariantType.find(params[:variant_type_id])
      product = params[:product_id].present? ? Product.find(params[:product_id]) : nil
      data = params[:rule] || {}

      if data[:supplier_item_id].blank?
        SupplyRule.where(
          product: product,
          variant_type: variant_type,
          rule_type: "consolidated"
        ).destroy_all

        redirect_to procurement_config_consolidated_path(
          product_id: product&.id, variant_type_id: variant_type.id
        ), notice: "Regla consolidada eliminada."
        return
      end

      rule = SupplyRule.find_or_initialize_by(
        product: product,
        variant_type: variant_type,
        rule_type: "consolidated"
      )

      rule.assign_attributes(
        supplier_item_id: data[:supplier_item_id],
        quantity_needed: data[:quantity_needed].presence || 1.0,
        variant_id: nil
      )

      if rule.save
        redirect_to procurement_config_consolidated_path(
          product_id: product&.id, variant_type_id: variant_type.id
        ), notice: "Regla consolidada guardada."
      else
        redirect_to procurement_config_consolidated_path(
          product_id: product&.id, variant_type_id: variant_type.id
        ), alert: "Error: #{rule.errors.full_messages.join(", ")}"
      end
    end
  end
end
