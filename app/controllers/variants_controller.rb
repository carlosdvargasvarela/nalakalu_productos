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
      sync_compatible_products
      sync_compatible_variants
      respond_to do |format|
        format.html { redirect_to @variant.variant_type, notice: "Variante creada." }
        format.turbo_stream
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @variant.assign_attributes(variant_params)
    sync_property_values

    if @variant.save
      sync_compatible_products
      sync_compatible_variants
      respond_to do |format|
        format.html { redirect_to @variant.variant_type, notice: "Variante actualizada." }
        format.turbo_stream
      end
    else
      render :edit, status: :unprocessable_entity
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

  def sync_compatible_products
    ids = Array(params.dig(:variant, :compatible_product_ids))
      .reject(&:blank?)
      .map(&:to_i)
      .uniq

    # Si no se enviaron IDs explícitos, no tocamos nada.
    # El after_create :auto_link_to_products se encargó al crear.
    return if ids.empty?

    @variant.compatibilities
      .where(compatible_type: "Product")
      .where.not(compatible_id: ids)
      .destroy_all

    existing = @variant.compatibilities
      .where(compatible_type: "Product")
      .pluck(:compatible_id)

    (ids - existing).each do |pid|
      @variant.compatibilities.find_or_create_by!(
        compatible_type: "Product",
        compatible_id: pid
      )
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
      :name, :display_name, :code, :provider_sku,
      :variant_type_id, :provider_id, :active,
      :technical_description,
      compatible_product_ids: [],
      compatible_variant_ids: [],
      variant_properties_attributes: [
        :id, :property_id, :property_value_id, :_destroy
      ]
    )
  end
end
