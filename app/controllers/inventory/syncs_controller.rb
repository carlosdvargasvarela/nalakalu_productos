class Inventory::SyncsController < Inventory::BaseController
  before_action :set_sync

  def show
    all_movements = @sync.inventory_movements
      .includes(:product, :showroom)
      .order(:order_number, :movement_type, :product_name_raw)

    @movement_groups = all_movements.group_by(&:order_number)
    @stat_confirmed  = all_movements.count { |m| m.status == "resolved" }
    @stat_suggested  = all_movements.count { |m| m.status == "unresolved" && m.showroom_id.present? && m.product_id.present? }
    @stat_unassigned = all_movements.count { |m| m.status == "unresolved" && (m.showroom_id.nil? || m.product_id.nil?) }
    @stat_ignored    = all_movements.count { |m| m.status == "ignored" }
    @products_for_select  = Product.where(active: true).order(:name)
    @showrooms_for_select = Showroom.active.order(:name)
    @families = Family.order(:name)

    @current_stock = InventoryMovement.net_stock_by_product_and_showroom
  end

  def confirm_matched
    count = @sync.inventory_movements
      .where(status: "unresolved")
      .where.not(product_id: nil)
      .update_all(status: "resolved")
    @sync.update!(unresolved_count: @sync.inventory_movements.unresolved.count)
    InventoryMovement.bust_stock_cache!
    redirect_to inventory_sync_path(@sync), notice: "#{count} movimiento(s) con producto detectado fueron confirmados."
  end

  def confirm
    if @sync.confirm!
      redirect_to inventory_path, notice: "Sincronización confirmada. Inventario actualizado."
    else
      redirect_to inventory_sync_path(@sync), alert: "Hay ítems sin resolver. Asígnalos o ignóralos antes de confirmar."
    end
  end

  def destroy
    @sync.destroy
    redirect_to inventory_path, notice: "Sincronización eliminada."
  end

  def bulk_ignore
    ids = params[:movement_ids].to_a.map(&:to_i).reject(&:zero?)
    return redirect_to inventory_sync_path(@sync), alert: "No seleccionaste ningún ítem." if ids.empty?
    @sync.inventory_movements.where(id: ids, status: "unresolved").update_all(status: "ignored")
    @sync.update!(unresolved_count: @sync.inventory_movements.unresolved.count)
    InventoryMovement.bust_stock_cache!
    redirect_to inventory_sync_path(@sync), notice: "#{ids.size} ítem(s) ignorados."
  end

  def bulk_assign_product
    ids = params[:movement_ids].to_a.map(&:to_i).reject(&:zero?)
    product = Product.find_by(id: params[:product_id])

    if ids.empty? || product.nil?
      return redirect_to inventory_sync_path(@sync), alert: "Selecciona un producto y al menos un ítem."
    end

    scope = @sync.inventory_movements.where(id: ids, status: "unresolved")
    resolved_count = scope.where.not(showroom_id: nil).update_all(product_id: product.id, status: "resolved")
    pending_showroom_count = scope.where(showroom_id: nil).update_all(product_id: product.id)

    @sync.update!(unresolved_count: @sync.inventory_movements.unresolved.count)
    InventoryMovement.bust_stock_cache!

    notice = "#{resolved_count} ítem(s) asignados a \"#{product.name}\"."
    notice += " #{pending_showroom_count} quedaron pendientes de seleccionar sala." if pending_showroom_count > 0
    redirect_to inventory_sync_path(@sync), notice: notice
  end

  private

  def set_sync
    @sync = InventorySync.find(params[:id])
  end
end
