class InventorySyncsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_sync

  def show
    @unresolved = @sync.inventory_movements.unresolved
      .order(:delivery_date, :product_name_raw)
    @resolved = @sync.inventory_movements.where(status: %w[resolved ignored])
      .includes(:product)
      .order(:sala, :movement_type, :product_name_raw)
    @products_for_select = Product.where(active: true).order(:name)
  end

  def confirm
    if @sync.confirm!
      redirect_to inventory_path, notice: "Sincronización confirmada. Inventario actualizado."
    else
      redirect_to inventory_sync_path(@sync),
        alert: "Hay ítems sin resolver. Asígnalos o ignóralos antes de confirmar."
    end
  end

  def destroy
    @sync.destroy
    redirect_to inventory_path, notice: "Sincronización eliminada."
  end

  private

  def set_sync
    @sync = InventorySync.find(params[:id])
  end
end
