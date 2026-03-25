# app/controllers/variants_controller.rb
class VariantsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_variant, only: %i[show edit update destroy move_to_type]

  def index
    @variants = Variant.all
      .includes(:variant_type, :property_values, :compatibilities)
      .order("variant_types.name, variants.name")
      .joins(:variant_type)
  end

  def show
    rule_ids = @variant.compatibilities
      .where(compatible_type: "ProductVariantRule")
      .pluck(:compatible_id)

    @compatible_products = Product
      .joins(:product_variant_rules)
      .where(product_variant_rules: {id: rule_ids})
      .distinct
      .order(:name)
  end

  def new
    @variant = Variant.new(variant_type_id: params[:variant_type_id], active: true)
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @variant = Variant.new(variant_params)
    sync_property_values

    if @variant.save
      sync_compatible_variants
      respond_to do |format|
        format.html { redirect_to @variant.variant_type, notice: "Variante creada." }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    @variant.assign_attributes(variant_params)
    sync_property_values

    if @variant.save
      sync_compatible_variants
      respond_to do |format|
        format.html { redirect_to @variant.variant_type, notice: "Variante actualizada." }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    type = @variant.variant_type
    @variant.destroy
    respond_to do |format|
      format.html { redirect_to variant_type_path(type), notice: "Variante eliminada." }
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@variant) }
    end
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
      redirect_to variant_type_path(new_type),
        notice: "Variante movida a '#{new_type.name}' exitosamente."
    else
      redirect_to variant_type_path(old_type),
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

  def sync_property_values
    return unless params.dig(:variant, :property_value_ids).present?

    selected_ids = params[:variant][:property_value_ids]
      .values
      .reject(&:blank?)
      .map(&:to_i)
      .uniq

    @variant.variant_properties
      .reject(&:new_record?)
      .select { |vp| selected_ids.exclude?(vp.property_value_id) }
      .each(&:mark_for_destruction)

    existing = @variant.variant_properties
      .reject(&:marked_for_destruction?)
      .map(&:property_value_id)

    (selected_ids - existing).each do |pv_id|
      @variant.variant_properties.build(property_value_id: pv_id)
    end
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
      :name, :display_name, :seller_name, :code,
      :variant_type_id, :active,
      :technical_description,
      compatible_variant_ids: [],
      variant_properties_attributes: [:id, :property_id, :property_value_id, :_destroy]
    )
  end
end
