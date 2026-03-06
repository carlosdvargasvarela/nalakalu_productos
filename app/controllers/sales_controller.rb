class SalesController < ApplicationController
  before_action :authenticate_user!

  def new
  end

  def search_products
    query = params[:q].to_s.strip

    return render json: [] if query.length < 2

    operator = Rails.env.production? ? "ILIKE" : "LIKE"

    products = Product.where(active: true)
      .where("name #{operator} ? OR base_code #{operator} ?", "%#{query}%", "%#{query}%")
      .order(:name)
      .limit(15)
      .select(:id, :name, :base_code)

    render json: products.map { |p| {id: p.id, name: p.name, base_code: p.base_code} }
  end

  def variants_for_product
    product = Product.includes(product_variant_rules: {variant_type: :variants})
      .find(params[:product_id])

    rules = product.product_variant_rules.order(:position).map do |rule|
      {
        rule_id: rule.id,
        variant_type_id: rule.variant_type.id,
        variant_type_name: rule.label.presence || rule.variant_type.name,
        label: rule.label,
        required: rule.required,
        separator: rule.separator,
        variants: rule.variant_type.variants.where(active: true).order(:name).map do |v|
          {
            id: v.id,
            name: v.display_name.presence || v.name,
            code: v.code,
            compatible_with: v.compatible_variant_ids
          }
        end
      }
    end

    render json: {base_code: product.base_code, rules: rules}
  end
end
