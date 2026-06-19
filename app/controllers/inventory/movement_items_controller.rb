class Inventory::MovementItemsController < Inventory::BaseController
  before_action :set_movement

  def update
    if params[:ignore]
      @movement.update!(status: "ignored")
      flash[:notice] = "Ítem marcado como ignorado."
      return redirect_to inventory_sync_path(@movement.inventory_sync)
    end

    product_id  = params.dig(:inventory_movement, :product_id).presence
    showroom_id = params.dig(:inventory_movement, :showroom_id).presence || @movement.showroom_id

    if product_id.nil?
      flash[:alert] = "Debes seleccionar un producto."
    elsif showroom_id.nil?
      flash[:alert] = "Debes seleccionar la sala de salida."
    else
      @movement.update!(product_id: product_id, showroom_id: showroom_id, status: "resolved")
      flash[:notice] = "Producto asignado correctamente."
    end

    redirect_to inventory_sync_path(@movement.inventory_sync)
  end

  private

  def set_movement
    @movement = InventoryMovement.find(params[:id])
  end
end
