class Inventory::SyncsController < Inventory::BaseController
  before_action :set_sync

  def show
    load_review_locals
    @families = Family.order(:name)
  end

  def confirm_matched
    count = @sync.inventory_movements
      .where(status: "unresolved")
      .where.not(product_id: nil)
      .update_all(status: "resolved")
    @sync.update!(unresolved_count: @sync.inventory_movements.unresolved.count)
    InventoryMovement.bust_stock_cache!
    respond_to do |format|
      format.html { redirect_to inventory_sync_path(@sync), notice: "#{count} movimiento(s) con producto detectado fueron confirmados." }
      format.turbo_stream { load_review_locals }
    end
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
    respond_to do |format|
      format.html { redirect_to inventory_sync_path(@sync), notice: "#{ids.size} ítem(s) ignorados." }
      format.turbo_stream { load_review_locals }
    end
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

    respond_to do |format|
      format.html { redirect_to inventory_sync_path(@sync), notice: notice }
      format.turbo_stream { load_review_locals }
    end
  end

  private

  def set_sync
    @sync = InventorySync.find(params[:id])
  end

  # Compartido por #show y por las acciones en lote (que responden con
  # turbo_stream para refrescar la tabla sin recargar la página completa).
  def load_review_locals
    @movement_groups = @sync.inventory_movements
      .includes(:product, :showroom)
      .order(:order_number, :movement_type, :product_name_raw)
      .group_by(&:order_number)
    @stats                = @sync.movement_stats
    @pending_count         = @stats[:suggested] + @stats[:unassigned]
    @products_for_select  = Product.cached_active_ordered
    @showrooms_for_select = Showroom.cached_active_ordered
    @current_stock        = InventoryMovement.net_stock_by_product_and_showroom
  end
end
