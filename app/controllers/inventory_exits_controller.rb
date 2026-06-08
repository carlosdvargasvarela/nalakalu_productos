class InventoryExitsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!

  def new
    @movement = InventoryMovement.new(movement_type: "exit", source: "manual", delivery_date: Date.current)
    @movement.assign_attributes(movement_params) if params[:inventory_movement].present?

    load_form_collections
    load_delivery_preview
    load_current_stock
  end

  def create
    @movement = InventoryMovement.new(
      movement_params.merge(movement_type: "exit", source: "manual", status: "resolved")
    )
    apply_stock_flag!
    load_form_collections

    if @movement.save
      notice = @movement.flag == "stock_missing" ? "Salida registrada con alerta de stock faltante." : "Salida registrada correctamente."
      redirect_to inventory_path, notice: notice
    else
      load_delivery_preview
      load_current_stock
      render :new, status: :unprocessable_entity
    end
  end

  private

  def movement_params
    params.fetch(:inventory_movement, {})
      .permit(:showroom_id, :product_id, :quantity, :order_number, :notes, :delivery_date)
  end

  def load_form_collections
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
    @products  = Product.where(active: true).order(:name)
  end

  def load_delivery_preview
    return if @movement.order_number.blank?

    deliveries = LogisticsApiClient.new.fetch_deliveries(order_number: @movement.order_number)
    @delivery_preview = Array(deliveries).first
    @delivery_preview_error = "No se encontró ningún pedido con ese número." unless @delivery_preview
  rescue => e
    @delivery_preview_error = "No se pudo consultar el pedido: #{e.message}"
  end

  def load_current_stock
    return unless @movement.product_id.present? && @movement.showroom_id.present?

    @current_stock = InventoryMovement.current_stock_for(
      product_id: @movement.product_id, showroom_id: @movement.showroom_id
    )
  end

  def apply_stock_flag!
    return unless @movement.product_id.present? && @movement.showroom_id.present?

    available = InventoryMovement.current_stock_for(
      product_id: @movement.product_id, showroom_id: @movement.showroom_id
    )
    return if @movement.quantity.to_f <= available

    @movement.flag = "stock_missing"
    @movement.notes = [
      @movement.notes.presence,
      "Alerta automática: se registró una salida de #{@movement.quantity} pero el stock calculado era #{available}."
    ].compact.join("\n\n")
  end
end
