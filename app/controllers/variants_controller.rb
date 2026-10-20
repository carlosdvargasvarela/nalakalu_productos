class VariantsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :set_variant, only: %i[show edit update destroy move_to_type]

  helper_method :compatible_products_for

  def index
    scope = Variant.includes(:variant_type, :review, :supplier_links).joins(:variant_type).order("variant_types.name, variants.name")
    scope = scope.where("variants.name LIKE ? OR variants.display_name LIKE ?", *["%#{params[:search].strip}%"] * 2) if params[:search].present?
    scope = scope.where(variant_type_id: params[:type_id]) if params[:type_id].present?
    scope = scope.where(active: false) if params[:filter] == "inactive"
    scope = scope.review_is(params[:review])
    @pagy, @variants = pagy(scope, limit: 50)
  end

  def show
    @compatible_products = compatible_products_for(@variant)
      end

  def new
    @variant = Variant.new(variant_type_id: params[:variant_type_id], active: true)
      end

  def edit
      end

  def create
    @variant = Variant.new(variant_params)

    if @variant.save
      sync_compatible_variants
      redirect_to variant_path(@variant), notice: "Variante creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @variant.assign_attributes(variant_params)

    if @variant.save
      sync_compatible_variants
      redirect_to variant_path(@variant), notice: "Variante actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    type = @variant.variant_type
    @variant.destroy
    redirect_to variants_path, notice: "Variante eliminada."
  end

  def move_to_type
    old_type = @variant.variant_type
    new_type = VariantType.find(params[:new_type_id])

    old_rule_ids = ProductVariantRule.where(variant_type_id: old_type.id).pluck(:id)
    Compatibility.where(
      variant_id: @variant.id,
      compatible_type: "ProductVariantRule",
      compatible_id: old_rule_ids
    ).destroy_all

    if @variant.update(variant_type: new_type)
      ProductVariantRule.where(variant_type_id: new_type.id).each do |rule|
        Compatibility.find_or_create_by!(
          variant_id: @variant.id,
          compatible_type: "ProductVariantRule",
          compatible_id: rule.id
        )
      end
      redirect_to variant_path(@variant),
        notice: "Variante movida a '#{new_type.name}' exitosamente."
    else
      redirect_to variant_path(@variant),
        alert: "No se pudo mover la variante."
    end
  end

  def import
    file = params[:file]
    if file.blank?
      redirect_to variants_path, alert: "Por favor, selecciona un archivo CSV."
      return
    end
    result = ImportVariantsService.call(file.tempfile.path)
    if result[:success]
      redirect_to variants_path,
        notice: "Importación exitosa: #{result[:created]} creados, #{result[:updated]} actualizados."
    else
      redirect_to variants_path,
        alert: "Importación con errores: #{result[:errors].count} errores encontrados."
    end
  end

  private

  def set_variant
    @variant = Variant.find(params[:id])
  end

  def compatible_products_for(variant)
    rule_ids = variant.compatibilities
      .where(compatible_type: "ProductVariantRule")
      .pluck(:compatible_id)
    Product
      .joins(:product_variant_rules)
      .where(product_variant_rules: {id: rule_ids})
      .distinct
      .order(:name)
  end

  def sync_compatible_variants
    ids = Array(params.dig(:variant, :compatible_variant_ids))
      .reject(&:blank?)
      .map(&:to_i)
      .uniq

    @variant.compatibilities
      .where(compatible_type: "Variant")
      .where.not(compatible_id: ids)
      .destroy_all

    existing = @variant.compatibilities
      .where(compatible_type: "Variant")
      .pluck(:compatible_id)

    (ids - existing).each do |vid|
      @variant.compatibilities.create!(compatible_type: "Variant", compatible_id: vid)
    end
  end

  def variant_params
    params.require(:variant).permit(
      :name, :display_name, :code,
      :variant_type_id, :active,
      :technical_description,
      compatible_variant_ids: []
    )
  end

  def bust_decoder_cache
    ProductDecoder.clear_cache!
  end
end
