# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_product, only: %i[show edit update destroy update_compatibilities]

  def index
    scope = Product
      .includes(:family, :product_variant_rules)
      .order(:name)

    if params[:search].present?
      term = "%#{params[:search].strip}%"
      scope = scope.where("products.name LIKE ? OR products.base_code LIKE ?", term, term)
    end

    scope = scope.where(family_id: params[:family_id]) if params[:family_id].present?

    case params[:status]
    when "active" then scope = scope.where(active: true)
    when "inactive" then scope = scope.where(active: false)
    end

    # ready/incomplete se resuelven post-query (dependen del mapa)
    filter_by_readiness = params[:status].in?(%w[ready incomplete])

    @pagy, @products = pagy(scope, limit: 150)

    product_ids = @products.map(&:id)

    # supplier_type map
    categories_by_product = SupplierItem
      .joins(:supply_rules, :provider)
      .where(supply_rules: {product_id: product_ids})
      .pluck("supply_rules.product_id", "providers.category")
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }

    @supplier_type_map = product_ids.index_with do |pid|
      cats = categories_by_product[pid] || []
      if cats.include?("interno") && cats.include?("externo") then "mixto"
      elsif cats.include?("externo") then "externo"
      elsif cats.include?("interno") then "interno"
      else "sin_definir"
      end
    end

    # procurement_ready map
    variant_type_ids_by_product = ProductVariantRule
      .where(product_id: product_ids)
      .pluck(:product_id, :variant_type_id)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last) }

    covered_pairs = SupplyRule
      .where(product_id: product_ids)
      .where.not(variant_type_id: nil)
      .pluck(:product_id, :variant_type_id)
      .to_set

    @procurement_ready_map = product_ids.index_with do |pid|
      required = variant_type_ids_by_product[pid] || []
      required.any? && required.all? { |vtid| covered_pairs.include?([pid, vtid]) }
    end

    # Filtro post-query para ready/incomplete
    if filter_by_readiness
      keep_ids = if params[:status] == "ready"
        @procurement_ready_map.select { |_, v| v }.keys
      else
        @procurement_ready_map.reject { |_, v| v }.keys
      end
      @products = @products.select { |p| keep_ids.include?(p.id) }
    end

    @selected_product = Product.find_by(id: params[:selected_id])

    @stats = {
      total: Product.count,
      active: Product.where(active: true).count,
      procurement_ready: @procurement_ready_map.count { |_, v| v },
      no_variants: Product.left_joins(:product_variant_rules)
        .where(product_variant_rules: {id: nil}).count
    }
  end

  def show
    respond_to do |format|
      format.html
      format.json { render :show }
    end
  end

  def new
    @product = Product.new
    @product.product_variant_rules.build
  end

  def edit
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      respond_to do |format|
        format.html { redirect_to products_path(selected_id: @product.id), notice: "Producto creado exitosamente." }
        format.turbo_stream { redirect_to products_path(selected_id: @product.id) }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      respond_to do |format|
        format.html { redirect_to products_path(selected_id: @product.id), notice: "Producto actualizado." }
        format.turbo_stream { redirect_to products_path(selected_id: @product.id) }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_compatibilities
    rule = @product.product_variant_rules.find(params[:rule_id])
    new_variant_ids = (params[:variant_ids] || []).map(&:to_i)

    Compatibility.transaction do
      rule.compatibilities.where.not(variant_id: new_variant_ids).destroy_all
      existing_ids = rule.compatibilities.pluck(:variant_id)
      (new_variant_ids - existing_ids).each do |v_id|
        rule.compatibilities.create!(variant_id: v_id, compatible_type: "ProductVariantRule")
      end
    end

    redirect_to products_path(selected_id: @product.id),
      notice: "Variantes de \"#{rule.display_name}\" actualizadas."
  end

  def destroy
    @product.destroy!
    redirect_to products_path, status: :see_other, notice: "Producto eliminado."
  end

  def import
    if params[:file].blank?
      redirect_to products_path, alert: "Selecciona un archivo CSV." and return
    end

    tmp_path = Rails.root.join("tmp", "import_products_#{SecureRandom.hex(8)}.csv")
    File.binwrite(tmp_path, params[:file].read)
    report = ImportProductsService.call(tmp_path.to_s)

    if report[:errors].any?
      flash[:alert] = "Importación con errores: #{report[:errors].first(3).join(" | ")}"
    else
      flash[:notice] = "✅ #{report[:created]} creados, #{report[:updated]} actualizados."
    end

    redirect_to products_path
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name, :base_code, :description, :active, :family_id,
      product_variant_rules_attributes: [
        :id, :variant_type_id, :position, :required, :separator, :label, :_destroy
      ]
    )
  end

  def bust_decoder_cache
    ProductDecoder.bust_cache!
  end
end
