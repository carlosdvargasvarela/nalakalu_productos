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
    sep = @settings.default_separator

    # Reglas reales del producto, ordenadas por position del variant_type
    product_rules = @product.product_variant_rules
      .joins(:variant_type)
      .reorder("variant_types.position ASC, product_variant_rules.id ASC")

    product_vt_ids = product_rules.map(&:variant_type_id).to_set

    # Reglas reales → incluyen sus variantes permitidas
    real_rules = product_rules.map do |pvr|
      {
        rule_id: pvr.id,
        ghost: false,
        variant_type_id: pvr.variant_type_id,
        variant_type_name: pvr.label.presence || pvr.variant_type.name,
        label: pvr.label,
        position: pvr.variant_type.position.to_i,
        required: pvr.required,
        keep_position: pvr.variant_type.keep_position,
        separator: pvr.separator.presence || sep,
        variants: pvr.allowed_variants.where(active: true).order(:name).map do |v|
          {
            id: v.id,
            name: v.seller_name,
            display_name: v.display_name.presence || v.name,
            compatible_with: v.compatibilities.where(compatible_type: "Variant").pluck(:compatible_id)
          }
        end
      }
    end

    # Tipos globales con keep_position: true que el producto NO tiene
    # → se insertan como posiciones fantasma (sin variantes seleccionables)
    ghost_rules = VariantType.where(keep_position: true, active: true)
      .where.not(id: product_vt_ids)
      .order(:position)
      .map do |vt|
        {
          rule_id: "ghost_#{vt.id}",
          ghost: true,
          variant_type_id: vt.id,
          variant_type_name: vt.name,
          label: nil,
          position: vt.position.to_i,
          required: false,
          keep_position: true,
          separator: sep,
          variants: []
        }
      end

    # Mezclar y ordenar por position global del variant_type
    all_rules = (real_rules + ghost_rules).sort_by { |r| r[:position] }

    render json: {
      base_code: @product.base_code,
      rules: all_rules,
      settings: {
        max_chars: @settings.max_chars_per_line,
        max_lines: @settings.max_lines,
        stock_options: @settings.stock_sala_options_array,  # ← array ahora
        prefix_length: @settings.prefix_length,
        use_prefixes: @settings.use_prefixes,
        default_separator: @settings.default_separator,
        show_stock_sala: @settings.show_stock_sala
      }
    }
  end
end
