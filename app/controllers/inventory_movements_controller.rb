class InventoryMovementsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_movement

  def update
    if params[:ignore]
      @movement.update!(status: "ignored")
      flash[:notice] = "Ítem marcado como ignorado."
    else
      product_id = params.dig(:inventory_movement, :product_id).presence
      if product_id
        @movement.update!(product_id: product_id, status: "resolved")
        flash[:notice] = "Producto asignado correctamente."
      else
        flash[:alert] = "Debes seleccionar un producto."
      end
    end

    redirect_to inventory_sync_path(@movement.inventory_sync)
  end

  private

  def set_movement
    @movement = InventoryMovement.find(params[:id])
  end
end
