class InventorySyncsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_sala_admin!
  before_action :set_sync, only: %i[show confirm destroy bulk_ignore confirm_matched]

  def show
    all_movements = @sync.inventory_movements
      .includes(:product, :showroom)
      .order(:order_number, :movement_type, :product_name_raw)

    @movement_groups  = all_movements.group_by(&:order_number)
    @stat_confirmed   = all_movements.count { |m| m.status == "resolved" }
    @stat_suggested   = all_movements.count { |m| m.status == "unresolved" && m.product_id.present? }
    @stat_unassigned  = all_movements.count { |m| m.status == "unresolved" && m.product_id.nil? }
    @stat_ignored     = all_movements.count { |m| m.status == "ignored" }
    @products_for_select = Product.where(active: true).order(:name)
    @families = Family.order(:name)
  end

  def confirm_matched
    count = @sync.inventory_movements
      .where(status: "unresolved")
      .where.not(product_id: nil)
      .update_all(status: "resolved")
    @sync.update!(unresolved_count: @sync.inventory_movements.unresolved.count)
    redirect_to inventory_sync_path(@sync),
      notice: "#{count} movimiento(s) con producto detectado fueron confirmados."
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
