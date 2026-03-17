class VariantsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_variant, only: %i[show edit update destroy]

  def index
    @variants = Variant.all
      .includes(:variant_type, :provider, :property_values, :compatibilities)
      .order("variant_types.name, variants.name")
      .joins(:variant_type)
  end

  def show
    @compatible_products = @variant.compatibilities
      .where(compatible_type: "Product")
      .includes(:compatible)
      .map(&:compatible)
      .compact
      .sort_by(&:name)
  end

  def new
    @variant = Variant.new
  end

  def edit
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

  def create
    @variant = Variant.new(variant_params)
    sync_property_values

    respond_to do |format|
      if @variant.save
        sync_compatible_products  # ← DESPUÉS del save, ya tiene ID
        sync_compatible_variants
        format.html { redirect_to @variant, notice: "Variante creada exitosamente." }
        format.json { render :show, status: :created, location: @variant }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @variant.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @variant.assign_attributes(variant_params)
    sync_property_values

    respond_to do |format|
      if @variant.save
        sync_compatible_products  # ← DESPUÉS del save también, por consistencia
        sync_compatible_variants
        format.html { redirect_to @variant, notice: "Variante actualizada exitosamente." }
        format.json { render :show, status: :ok, location: @variant }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @variant.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @variant.destroy!
    respond_to do |format|
      format.html { redirect_to variants_path, status: :see_other, notice: "Variante eliminada." }
      format.json { head :no_content }
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

  # ← Ahora siempre corre DESPUÉS de save, con ID garantizado
  def sync_compatible_products
    ids = Array(params.dig(:variant, :compatible_product_ids))
      .reject(&:blank?)
      .map(&:to_i)
      .uniq

    # Borrar los que ya no están marcados
    @variant.compatibilities
      .where(compatible_type: "Product")
      .where.not(compatible_id: ids)
      .destroy_all

    # Crear los nuevos
    existing = @variant.compatibilities
      .where(compatible_type: "Product")
      .pluck(:compatible_id)

    (ids - existing).each do |pid|
      @variant.compatibilities.create!(compatible_type: "Product", compatible_id: pid)
    end
  end

  # Sincroniza compatibilidades entre variantes (sección 4 del form)
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
      :variant_type_id,
      :provider_id,
      :name,
      :display_name,
      :code,
      :provider_sku,
      :active,
      :technical_description,
      variant_properties_attributes: [:id, :property_value_id, :_destroy]
    )
  end
end
