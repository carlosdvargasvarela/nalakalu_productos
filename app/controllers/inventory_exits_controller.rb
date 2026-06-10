class InventoryExitsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_sala_admin!

  def new
    @showroom_id  = params[:showroom_id]
    @order_number = params[:order_number]
    @showrooms    = Showroom.active.order(is_main: :desc, name: :asc)
    @products     = Product.where(active: true).order(:name)
    @families     = Family.order(:name)
    @items        = [{ product_id: nil, quantity: nil, notes: nil }]
    load_delivery_preview
  end

  def create
    @showrooms    = Showroom.active.order(is_main: :desc, name: :asc)
    @products     = Product.where(active: true).order(:name)
    @showroom_id  = params[:showroom_id]
    @order_number = params[:order_number]

    items_input = parse_items

    if items_input.empty?
      flash.now[:alert] = "Debes agregar al menos un producto."
      @items = [{ product_id: nil, quantity: nil, notes: nil }]
      load_delivery_preview
      return render(:new, status: :unprocessable_entity)
    end

    movements = []
    @errors   = []

    items_input.each_with_index do |item, i|
      m = InventoryMovement.new(
        showroom_id:   @showroom_id,
        product_id:    item[:product_id],
        quantity:      item[:quantity],
        notes:         item[:notes],
        order_number:  @order_number,
        delivery_date: params[:delivery_date].presence || Date.current,
        movement_type: "exit",
        source:        "manual",
        status:        "resolved"
      )
      apply_stock_flag!(m)
      if m.valid?
        movements << m
      else
        @errors << { index: i, messages: m.errors.full_messages }
      end
    end

    if @errors.empty?
      movements.each(&:save!)
      flagged = movements.count { |m| m.flag == "stock_missing" }
      notice  = flagged > 0 ?
        "#{movements.size} salida(s) registradas (#{flagged} con alerta de stock faltante)." :
        "#{movements.size} salida(s) registradas correctamente."
      redirect_to inventory_path, notice: notice
    else
      @items = items_input
      load_delivery_preview
      render :new, status: :unprocessable_entity
    end
  end

  private

  def parse_items
    return [] unless params[:items].is_a?(ActionController::Parameters)
    params[:items].values
      .map { |i| i.permit(:product_id, :quantity, :notes).to_h.symbolize_keys }
      .reject { |i| i[:product_id].blank? && i[:quantity].blank? }
  end

  def load_delivery_preview
    return if @order_number.blank?
    deliveries = LogisticsApiClient.new.fetch_deliveries(order_number: @order_number)
    @delivery_preview = Array(deliveries).first
    @delivery_preview_error = "No se encontró ningún pedido con ese número." unless @delivery_preview
  rescue => e
    @delivery_preview_error = "No se pudo consultar el pedido: #{e.message}"
  end

  def apply_stock_flag!(movement)
    return unless movement.product_id.present? && movement.showroom_id.present?
    available = InventoryMovement.current_stock_for(
      product_id: movement.product_id, showroom_id: movement.showroom_id
    )
    return if movement.quantity.to_f <= available
    movement.flag = "stock_missing"
    movement.notes = [
      movement.notes.presence,
      "Alerta automática: salida de #{movement.quantity} pero stock calculado era #{available}."
    ].compact.join("\n\n")
  end
end
