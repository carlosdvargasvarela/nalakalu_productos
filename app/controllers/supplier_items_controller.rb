class SupplierItemsController < ApplicationController
  before_action :set_supplier_item, only: %i[edit update destroy]

  def index
    @supplier_items = SupplierItem.includes(:provider).order("providers.name, supplier_items.name")
  end

  def new
    @supplier_item = SupplierItem.new
    @supplier_item.provider_id = params[:provider_id] if params[:provider_id]
  end

  def create
    @supplier_item = SupplierItem.new(supplier_item_params)
    if @supplier_item.save
      redirect_to provider_path(@supplier_item.provider),
        notice: "Pieza '#{@supplier_item.name}' creada correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @supplier_item.update(supplier_item_params)
      redirect_to provider_path(@supplier_item.provider),
        notice: "Pieza actualizada correctamente."
    else
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

  def supplier_item_params
    params.require(:supplier_item).permit(
      :provider_id, :name, :sku, :unit, :cost, :currency
    )
  end
end
