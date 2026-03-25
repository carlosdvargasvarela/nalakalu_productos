class SupplierItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_supplier_item, only: %i[show edit update destroy]

  def index
    @supplier_items = SupplierItem
      .includes(:provider, supplier_item_properties: {property_value: :property})
      .order("providers.name, supplier_items.name")
      .joins(:provider)
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
  end

  def create
    @supplier_item = SupplierItem.new(supplier_item_params)

    if @supplier_item.save
      sync_item_properties
      redirect_to provider_path(@supplier_item.provider),
        notice: "Pieza '#{@supplier_item.name}' creada correctamente."
    else
      @properties = Property.where(active: true).includes(:property_values).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @properties = Property.where(active: true).includes(:property_values).order(:name)
  end

  def update
    if @supplier_item.update(supplier_item_params)
      sync_item_properties
      redirect_to provider_path(@supplier_item.provider),
        notice: "Pieza actualizada correctamente."
    else
      @properties = Property.where(active: true).includes(:property_values).order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    provider = @supplier_item.provider
    @supplier_item.destroy
    redirect_to provider_path(provider), notice: "Pieza eliminada."
  end

  private

  def set_supplier_item
    @supplier_item = SupplierItem.find(params[:id])
  end

  # Sincroniza los property_values seleccionados con supplier_item_properties
  # Espera params[:property_value_ids] como array de IDs
  def sync_item_properties
    selected_ids = Array(params[:property_value_ids])
      .reject(&:blank?)
      .map(&:to_i)
      .uniq

    # Eliminar los que ya no están seleccionados
    @supplier_item.supplier_item_properties
      .where.not(property_value_id: selected_ids)
      .destroy_all

    # Crear los nuevos
    existing_ids = @supplier_item.supplier_item_properties.pluck(:property_value_id)
    (selected_ids - existing_ids).each_with_index do |pv_id, index|
      @supplier_item.supplier_item_properties.create!(
        property_value_id: pv_id,
        position: index
      )
    end
  end

  def supplier_item_params
    params.require(:supplier_item).permit(
      :provider_id, :name, :sku, :unit, :default_cost, :active
    )
  end
end
