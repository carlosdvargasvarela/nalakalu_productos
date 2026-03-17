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
      notice = "Importación exitosa: #{result[:created]} creados, #{result[:updated]} actualizados."
      redirect_to variants_path, notice: notice
    else
      alert = "Importación con errores: #{result[:errors].count} errores encontrados."
      redirect_to variants_path, alert: alert
    end
  end

  def create
    @variant = Variant.new(variant_params)
    sync_property_values
    sync_compatible_products

    respond_to do |format|
      if @variant.save
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
    sync_compatible_products

    respond_to do |format|
      if @variant.save
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

  # Sincroniza property_value_ids: un valor por propiedad
  # Viene como params[:variant][:property_value_ids] => { "1" => "5", "2" => "" }
  def sync_property_values
    return unless params[:variant][:property_value_ids].present?

    selected_ids = params[:variant][:property_value_ids]
      .values
      .reject(&:blank?)
      .map(&:to_i)
      .uniq

    # Destruir los que ya no están
    @variant.variant_properties
      .where.not(property_value_id: selected_ids)
      .destroy_all

    # Agregar los nuevos
    existing = @variant.variant_properties.pluck(:property_value_id)
    (selected_ids - existing).each do |pv_id|
      @variant.variant_properties.build(property_value_id: pv_id)
    end
  end

  # Sincroniza compatibilidades con Productos
  def sync_compatible_products
    return unless params[:variant][:compatible_product_ids].present?

    ids = params[:variant][:compatible_product_ids]
      .reject(&:blank?)
      .map(&:to_i)
      .uniq

    @variant.compatibilities
      .where(compatible_type: "Product")
      .where.not(compatible_id: ids)
      .destroy_all

    existing = @variant.compatibilities
      .where(compatible_type: "Product")
      .pluck(:compatible_id)

    (ids - existing).each do |pid|
      @variant.compatibilities.build(compatible_type: "Product", compatible_id: pid)
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
      compatible_variant_ids: [],
      variant_properties_attributes: [:id, :property_value_id, :_destroy]
    )
  end
end
