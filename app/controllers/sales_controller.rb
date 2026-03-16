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
    @product = Product.includes(product_variant_rules: :variant_type).find(params[:product_id])

    rules = @product.product_variant_rules.order(:position).map do |rule|
      # FILTRO: Solo variantes compatibles con este producto específico
      scope = @product.compatible_variants_for(rule.variant_type)

      {
        rule_id: rule.id,
        variant_type_name: rule.label.presence || rule.variant_type.name,
        required: rule.required,
        separator: rule.separator,
        variants: scope.where(active: true).order(:name).map do |v|
          {
            id: v.id,
            name: v.seller_name,
            # Usamos display_name para el código final, fallback al name
            display_name: v.display_name.presence || v.name,
            compatible_with: v.compatibilities.where(compatible_type: "Variant").pluck(:compatible_id)
          }
        end
      }
    end

    render json: {base_code: @product.base_code, rules: rules}
  end
end
