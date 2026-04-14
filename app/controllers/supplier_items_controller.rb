class SupplierItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_supplier_item, only: %i[show edit update destroy]

  def index
    @supplier_items = SupplierItem
      .includes(:provider)
      .includes(supplier_item_properties: {property_value: :property})
      .order("providers.name ASC, supplier_items.name ASC")
  end

  def show
    @supply_rules = @supplier_item.supply_rules
      .includes(:product, :variant, :variant_type)
      .order("products.name, variants.name")
  end

  def new
    @supplier_item = SupplierItem.new
    @supplier_item.provider_id = params[:provider_id] if params[:provider_id]
    @properties = Property.where(active: true).includes(:property_values).order(:name)
    @variant_types = VariantType.where(active: true).includes(:variants).order(:name)
  end

  def create
    @supplier_item = SupplierItem.new(supplier_item_params)

    if @supplier_item.save
      sync_item_properties
      redirect_to provider_path(@supplier_item.provider),
        notice: "Pieza '#{@supplier_item.name}' creada correctamente."
    else
      @properties = Property.where(active: true).includes(:property_values).order(:name)
      @variant_types = VariantType.where(active: true).includes(:variants).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @properties = Property.where(active: true).includes(:property_values).order(:name)
    @variant_types = VariantType.where(active: true).includes(:variants).order(:name)
  end

  def update
    if @supplier_item.update(supplier_item_params)
      sync_item_properties
      redirect_to provider_path(@supplier_item.provider),
        notice: "Pieza actualizada correctamente."
    else
      @properties = Property.where(active: true).includes(:property_values).order(:name)
      @variant_types = VariantType.where(active: true).includes(:variants).order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    provider = @supplier_item.provider
    @supplier_item.destroy
    redirect_to provider_path(provider), notice: "Pieza eliminada."
  end

  def import
    if params[:file].present?
      unless params[:file].original_filename.downcase.end_with?(".csv")
        return redirect_to supplier_items_path, alert: "Por favor sube un archivo en formato CSV."
      end

      temp_dir = Rails.root.join("tmp", "imports")
      FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
      file_path = temp_dir.join("supplier_items_#{Time.now.to_i}_#{params[:file].original_filename}")
      File.binwrite(file_path, params[:file].read)

      ImportSupplierItemsJob.perform_later(file_path.to_s, current_user.id)

      redirect_to supplier_items_path,
        notice: "La importación de piezas ha comenzado. Los cambios aparecerán en breve."
    else
      redirect_to supplier_items_path, alert: "Debes seleccionar un archivo CSV para importar."
    end
  end

  private

  def set_supplier_item
    @supplier_item = SupplierItem.find(params[:id])
  end

  # Sincroniza propiedades simples Y especificaciones de variante
  def sync_item_properties
    # ✅ Usamos los parámetros permitidos para evitar UnfilteredParameters
    safe_params = extra_properties_params

    ActiveRecord::Base.transaction do
      # ── 1. PROPERTIES (Fijas) ─────────────────────────
      # Convertimos el hash de IDs a un array de enteros limpios
      selected_pv_ids = (safe_params[:property_value_ids] || {})
        .to_h.values
        .reject(&:blank?)
        .map(&:to_i)
        .uniq

      # Eliminar las que ya no están seleccionadas
      @supplier_item.supplier_item_properties
        .properties
        .where.not(property_value_id: selected_pv_ids)
        .delete_all

      # Obtener las que ya existen para no duplicar
      existing_pv_ids = @supplier_item.supplier_item_properties
        .properties
        .pluck(:property_value_id)

      # Crear las nuevas
      (selected_pv_ids - existing_pv_ids).each_with_index do |pv_id, idx|
        @supplier_item.supplier_item_properties.create!(
          property_value_id: pv_id,
          spec_type: "property",
          position: idx
        )
      end

      # ── 2. SPECS (LABELS dinámicos como F1, F2) ────────
      incoming_labels = Array(safe_params[:spec_labels])
        .map(&:strip)
        .reject(&:blank?)

      # Eliminar labels que ya no vienen en el form
      @supplier_item.supplier_item_properties
        .specs
        .where.not(label: incoming_labels)
        .delete_all

      # Posicionamiento después de las propiedades fijas
      property_count = selected_pv_ids.size

      incoming_labels.each_with_index do |label, idx|
        # Buscamos o inicializamos para mantener consistencia
        prop = @supplier_item.supplier_item_properties
          .specs
          .find_or_initialize_by(label: label)

        prop.update!(
          spec_type: "spec",
          position: property_count + idx
        )
      end
    end
  end

  def supplier_item_params
    params.require(:supplier_item).permit(:provider_id, :name, :sku, :unit, :default_cost, :active)
  end

  # Permite property_value_ids como Hash y spec_labels como Array
  def extra_properties_params
    params.permit(property_value_ids: {}, spec_labels: [])
  end
end
