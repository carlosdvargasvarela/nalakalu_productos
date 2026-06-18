class Inventory::MovementsController < Inventory::BaseController
  def index
    scope = InventoryMovement
      .confirmed_only.resolved
      .includes(:product, :showroom, :inventory_sync)
      .order(delivery_date: :desc, created_at: :desc)

    scope = scope.where(showroom_id: params[:showroom_id])     if params[:showroom_id].present?
    scope = scope.where(product_id: params[:product_id])       if params[:product_id].present?
    scope = scope.where(movement_type: params[:movement_type]) if params[:movement_type].present?
    scope = scope.where("delivery_date >= ?", params[:from])   if params[:from].present?
    scope = scope.where("delivery_date <= ?", params[:to])     if params[:to].present?

    @movements = scope.limit(300)
    @showrooms = Showroom.active.order(:name)
    @products  = Product.where(active: true).order(:name)
    @filter    = params.permit(:showroom_id, :product_id, :movement_type, :from, :to).to_h
  end

  def bulk_destroy
    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    return redirect_to inventory_movements_log_path(current_filter), alert: "No seleccionaste ningún movimiento." if ids.empty?

    movements = InventoryMovement.where(id: ids, source: "manual")
    count = movements.count
    movements.destroy_all
    redirect_to inventory_movements_log_path(current_filter), notice: "#{count} movimiento(s) eliminado(s)."
  end

  def bulk_export
    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    return redirect_to inventory_movements_log_path(current_filter), alert: "No seleccionaste ningún movimiento." if ids.empty?

    movements = InventoryMovement.where(id: ids).includes(:product, :showroom).order(delivery_date: :desc)
    send_data InventoryMovementsExportService.call(movements),
      filename: "movimientos_#{Date.current.iso8601}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def bulk_reassign_showroom
    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    new_showroom_id = params[:new_showroom_id].presence

    if ids.empty? || new_showroom_id.blank?
      return redirect_to inventory_movements_log_path(current_filter), alert: "Selecciona una sala y al menos un movimiento."
    end

    count = InventoryMovement.where(id: ids, source: "manual").update_all(showroom_id: new_showroom_id)
    redirect_to inventory_movements_log_path(current_filter), notice: "#{count} movimiento(s) reasignado(s) de sala."
  end

  def bulk_edit_note
    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    note = params[:note].presence
    order_number = params[:order_number].presence

    if ids.empty? || (note.nil? && order_number.nil?)
      return redirect_to inventory_movements_log_path(current_filter), alert: "Selecciona movimientos y completa al menos un campo."
    end

    changes = {}
    changes[:notes] = note if note
    changes[:order_number] = order_number if order_number
    count = InventoryMovement.where(id: ids, source: "manual").update_all(changes)
    redirect_to inventory_movements_log_path(current_filter), notice: "#{count} movimiento(s) actualizado(s)."
  end

  private

  def current_filter
    params.permit(:showroom_id, :product_id, :movement_type, :from, :to).to_h
  end
end
