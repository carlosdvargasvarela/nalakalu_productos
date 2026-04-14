class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_product, only: %i[show edit update destroy update_compatibilities]

  def index
    @products = Product.all
      .includes(:family, :product_variant_rules)
      .order(:name)

    product_ids = @products.map(&:id)

    # Precalcular supplier_type: 1 sola query
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

    # Precalcular procurement_ready?: 2 queries
    variant_type_ids_by_product = ProductVariantRule
      .where(product_id: product_ids)
      .pluck(:product_id, :variant_type_id)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last) }

    covered_pairs = SupplyRule
      .where(product_id: product_ids)
      .where.not(variant_type_id: nil)
      .pluck(:product_id, :variant_type_id)
      .map { |pid, vtid| [pid, vtid] }
      .to_set

    @procurement_ready_map = product_ids.index_with do |pid|
      required = variant_type_ids_by_product[pid] || []
      required.any? && required.all? { |vtid| covered_pairs.include?([pid, vtid]) }
    end

    @selected_product = Product.find_by(id: params[:selected_id])

    @stats = {
      total: @products.count,
      active: @products.count(&:active?),
      procurement_ready: @procurement_ready_map.count { |_, v| v },
      no_variants: @products.count { |p| p.product_variant_rules.empty? }
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
end
