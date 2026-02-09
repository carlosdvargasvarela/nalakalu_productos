class SalesController < ApplicationController
  before_action :authenticate_user!

  def new
    @products = Product.where(active: true).includes(product_variant_rules: :variant_type)
  end

  def variants_for_product
    product = Product.includes(product_variant_rules: {variant_type: :variants}).find(params[:product_id])

    rules = product.product_variant_rules.map do |rule|
      {
        rule_id: rule.id,
        variant_type_id: rule.variant_type.id,
        variant_type_name: rule.display_name,
        required: rule.required,
        separator: rule.separator,
        variants: rule.variant_type.variants.where(active: true).map do |v|
          {
            id: v.id,
            name: v.name,
            code: v.code,
            compatible_with: v.compatible_variant_ids
          }
        end
      }
    end

    render json: {
      base_code: product.base_code,
      rules: rules
    }
  end
end
