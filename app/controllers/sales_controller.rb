class SalesController < ApplicationController
  before_action :authenticate_user!

  def new
    @settings = CodeSetting.current
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
    @product = Product.find(params[:product_id])
    @settings = CodeSetting.current

    rules = @product.product_variant_rules
      .joins(:variant_type)
      .reorder("variant_types.position ASC, product_variant_rules.id ASC")
      .map do |rule|
        {
          rule_id: rule.id,
          variant_type_name: rule.label.presence || rule.variant_type.name,
          label: rule.label,
          required: rule.required,
          keep_position: rule.variant_type.keep_position,
          separator: rule.separator.presence || @settings.default_separator,
          variants: rule.allowed_variants.where(active: true).order(:name).map do |v|
            {
              id: v.id,
              name: v.seller_name,
              display_name: v.display_name.presence || v.name,
              compatible_with: v.compatibilities.where(compatible_type: "Variant").pluck(:compatible_id)
            }
          end
        }
      end

    render json: {
      base_code: @product.base_code,
      rules: rules,
      settings: {
        max_chars: @settings.max_chars_per_line,
        max_lines: @settings.max_lines,
        stock_label: @settings.stock_sala_label,
        prefix_length: @settings.prefix_length,
        use_prefixes: @settings.use_prefixes,
        default_separator: @settings.default_separator,
        show_stock_sala: @settings.show_stock_sala
      }
    }
  end
end
