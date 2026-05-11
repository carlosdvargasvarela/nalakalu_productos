class InventoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!

  def index
    @pending_syncs = InventorySync.pending.ordered
    @recent_syncs  = InventorySync.confirmed.ordered.limit(5)

    raw = InventoryMovement.stock_by_product_and_sala
    @stock, @product_ids = build_stock_table(raw)
    @products = Product.where(id: @product_ids).order(:name).index_by(&:id)
    @salas = InventoryMovement::SALAS

    @from = params[:from] || Date.current.beginning_of_week.to_s
    @to   = params[:to]   || Date.current.end_of_week.to_s
  end

  def sync
    from = params[:from] || Date.current.beginning_of_week.to_s
    to   = params[:to]   || Date.current.end_of_week.to_s

    SyncInventoryJob.perform_later(from: from, to: to, user_id: current_user.id)
    redirect_to inventory_path, notice: "Sincronización de inventario iniciada. Refresca en unos segundos."
  end

  def new_initial_stock
    @movement = InventoryMovement.new(movement_type: "initial", delivery_date: Date.current)
    @products = Product.where(active: true).order(:name)
    @salas    = InventoryMovement::SALAS
  end

  def create_initial_stock
    @movement = InventoryMovement.new(
      initial_stock_params.merge(movement_type: "initial", status: "resolved")
    )
    if @movement.save
      redirect_to inventory_path, notice: "Stock inicial cargado correctamente."
    else
      @products = Product.where(active: true).order(:name)
      @salas    = InventoryMovement::SALAS
      render :new_initial_stock, status: :unprocessable_entity
    end
  end

  def product_movements
    @product = Product.find(params[:product_id])
    @movements = InventoryMovement
      .confirmed_only
      .resolved
      .where(product_id: @product.id)
      .order(delivery_date: :desc, created_at: :desc)
      .limit(50)
    render partial: "inventories/product_movements_modal",
           locals: { product: @product, movements: @movements }
  end

  private

  # raw = { [product_id, sala, movement_type] => qty }
  # Returns [stock_hash, product_ids]
  # stock_hash = { [product_id, sala] => net_quantity }
  def build_stock_table(raw)
    stock = Hash.new(0)
    raw.each do |(product_id, sala, movement_type), qty|
      factor = movement_type.in?(%w[entry initial]) ? 1 : -1
      stock[[product_id, sala]] += factor * qty
    end
    product_ids = stock.keys.map(&:first).uniq
    [stock, product_ids]
  end

  def initial_stock_params
    params.require(:inventory_movement).permit(:product_id, :sala, :quantity, :delivery_date, :notes)
  end
end
