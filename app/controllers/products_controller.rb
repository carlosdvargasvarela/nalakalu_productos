# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :set_product, only: %i[show edit update destroy update_compatibilities]

  def index
    scope = Product
      .includes(:family, product_variant_rules: :variant_type)
      .order(:name)

    if params[:search].present?
      term = "%#{params[:search].strip}%"
      scope = scope.where("products.name LIKE ? OR products.base_code LIKE ?", term, term)
    end

    scope = scope.where(family_id: params[:family_id]) if params[:family_id].present?

    case params[:status]
    when "active" then scope = scope.where(active: true)
    when "inactive" then scope = scope.where(active: false)
    when "no_price" then scope = scope.where(list_price: nil)
    when "pending", "approved", "needs_changes"
      ids = Review.where(reviewable_type: "Product", status: params[:status]).select(:reviewable_id)
      scope = (params[:status] == "pending") ? scope.where.not(id: Review.where(reviewable_type: "Product").where.not(status: "pending").select(:reviewable_id)) : scope.where(id: ids)
    end

    @pagy, @products = pagy(scope.includes(:review), limit: 150)

    @selected_product = Product.find_by(id: params[:selected_id])

    active_counts = Product.group(:active).count
    @stats = {
      total:              active_counts.values.sum,
      active:             active_counts[true].to_i,
      no_price:           Product.where(list_price: nil).count,
      no_variants:        Product.left_joins(:product_variant_rules)
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
      redirect_to products_path(selected_id: @product.id), notice: "Producto creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      redirect_to products_path(selected_id: @product.id), notice: "Producto actualizado."
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

  def bulk_activate
    bulk_set_active(true)
  end

  def bulk_deactivate
    bulk_set_active(false)
  end

  private

  def bulk_set_active(active)
    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    return redirect_to products_path(current_filter), alert: "No seleccionaste ningún producto." if ids.empty?

    count = 0
    Product.where(id: ids).find_each do |product|
      count += 1 if product.update(active: active)
    end

    verb = active ? "activado" : "desactivado"
    redirect_to products_path(current_filter), notice: "#{count} producto(s) #{verb}(s)."
  end

  def current_filter
    params.permit(:search, :family_id, :status, :selected_id).to_h
  end

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:list_price, 
      :name, :base_code, :description, :active, :family_id,
      product_variant_rules_attributes: [
        :id, :variant_type_id, :position, :required, :separator, :label, :_destroy
      ]
    )
  end

  def bust_decoder_cache
    ProductDecoder.clear_cache!
  end
end
