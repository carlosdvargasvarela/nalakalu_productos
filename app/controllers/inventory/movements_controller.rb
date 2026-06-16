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
    return redirect_to inventory_movements_log_path, alert: "No seleccionaste ningún movimiento." if ids.empty?

    movements = InventoryMovement.where(id: ids, source: "manual")
    count = movements.count
    movements.destroy_all
    redirect_to inventory_movements_log_path, notice: "#{count} movimiento(s) eliminado(s)."
  end
end
