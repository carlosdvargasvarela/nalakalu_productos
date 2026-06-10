class InventorySyncsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_sala_admin!
  before_action :set_sync, only: %i[show confirm destroy bulk_ignore]

  def show
    @unresolved = @sync.inventory_movements.unresolved
      .order(:delivery_date, :product_name_raw)
    @resolved = @sync.inventory_movements.where(status: %w[resolved ignored])
      .includes(:product, :showroom)
      .order("showrooms.name", :movement_type, :product_name_raw)
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

  def bulk_ignore
    ids = params[:movement_ids].to_a.map(&:to_i).reject(&:zero?)
    if ids.empty?
      return redirect_to inventory_sync_path(@sync), alert: "No seleccionaste ningún ítem."
    end
    @sync.inventory_movements.where(id: ids, status: "unresolved").update_all(status: "ignored")
    @sync.update!(unresolved_count: @sync.inventory_movements.unresolved.count)
    redirect_to inventory_sync_path(@sync), notice: "#{ids.size} ítem(s) ignorados."
  end

  private

  def set_sync
    @sync = InventorySync.find(params[:id])
  end
end
