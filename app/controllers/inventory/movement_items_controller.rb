class Inventory::MovementItemsController < Inventory::BaseController
  before_action :set_movement

  def update
    @sync = @movement.inventory_sync

    if params[:ignore]
      @movement.update!(status: "ignored")
      @notice = "Ítem marcado como ignorado."
    else
      product_id  = params.dig(:inventory_movement, :product_id).presence
      showroom_id = params.dig(:inventory_movement, :showroom_id).presence || @movement.showroom_id

      if product_id.nil?
        @error = "Debes seleccionar un producto."
      elsif showroom_id.nil?
        @error = "Debes seleccionar la sala de salida."
      else
        @movement.update!(product_id: product_id, showroom_id: showroom_id, status: "resolved")
        @notice = "Producto asignado correctamente."
      end
    end

    respond_to do |format|
      format.html { redirect_to inventory_sync_path(@sync), notice: @notice, alert: @error }
      format.turbo_stream { load_row_update_locals }
    end
  end

  private

  def set_movement
    @movement = InventoryMovement.find(params[:id])
  end

  def load_row_update_locals
    @order_number          = @movement.order_number
    @order_group_movements = @sync.inventory_movements
      .where(order_number: @order_number)
      .includes(:product, :showroom)
      .order(:movement_type, :product_name_raw)
    @current_stock         = InventoryMovement.net_stock_by_product_and_showroom
    @showrooms_for_select  = Showroom.cached_active_ordered
    @products_for_select   = Product.cached_active_ordered
    @stats                 = @sync.movement_stats
    @pending_count         = @stats[:suggested] + @stats[:unassigned]
  end
end
