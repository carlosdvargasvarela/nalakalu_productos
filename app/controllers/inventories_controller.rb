class InventoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_sala_admin!

  def index
    @pending_syncs = InventorySync.pending.ordered
    @recent_syncs  = InventorySync.confirmed.ordered.limit(5)

    raw = InventoryMovement.stock_by_product_and_showroom
    @stock, @product_ids = build_stock_table(raw)
    @products  = Product.where(id: @product_ids).order(:name).index_by(&:id)
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
    @flagged_count = InventoryMovement.flagged.count

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
    @products  = Product.where(active: true).order(:name)
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
    @families  = Family.order(:name)
  end

  def create_initial_stock
    showroom_id    = params[:showroom_id].presence
    reference_date = params[:delivery_date].presence || Date.current.to_s
    notes          = params[:notes].presence
    items          = parse_initial_stock_items

    unless showroom_id
      return redirect_to new_inventory_initial_stock_path, alert: "Debes seleccionar una sala."
    end
    if items.empty?
      return redirect_to new_inventory_initial_stock_path, alert: "Agrega al menos un producto con cantidad."
    end

    saved  = []
    errors = []

    items.each do |item|
      m = InventoryMovement.new(
        movement_type: "initial",
        source:        "manual",
        status:        "resolved",
        showroom_id:   showroom_id,
        product_id:    item[:product_id],
        quantity:      item[:quantity],
        delivery_date: reference_date,
        notes:         notes
      )
      if m.save
        saved << m
      else
        label = Product.find_by(id: item[:product_id])&.name || "ítem"
        errors << "#{label}: #{m.errors.full_messages.join(', ')}"
      end
    end

    flash[:alert] = "Algunos ítems no se guardaron: #{errors.join('; ')}" if errors.any?

    if saved.any?
      redirect_to inventory_path, notice: "#{saved.size} producto(s) de stock inicial cargados."
    else
      redirect_to new_inventory_initial_stock_path, alert: "No se guardó ningún ítem."
    end
  end

  def showroom_stock
    @showroom  = Showroom.find(params[:showroom_id])
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)

    raw = InventoryMovement
      .confirmed_only
      .resolved
      .where.not(product_id: nil)
      .where(showroom_id: @showroom.id)
      .group(:product_id, :movement_type)
      .sum(:quantity)

    @stock = Hash.new(0)
    raw.each do |(product_id, movement_type), qty|
      @stock[product_id] += movement_type.in?(%w[entry initial]) ? qty : -qty
    end
    @stock.reject! { |_, qty| qty.zero? }

    @products = Product.where(id: @stock.keys).order(:name).index_by(&:id)
  end

  def movements_log
    scope = InventoryMovement
      .confirmed_only
      .resolved
      .includes(:product, :showroom, :inventory_sync)
      .order(delivery_date: :desc, created_at: :desc)

    scope = scope.where(showroom_id: params[:showroom_id])   if params[:showroom_id].present?
    scope = scope.where(product_id: params[:product_id])     if params[:product_id].present?
    scope = scope.where(movement_type: params[:movement_type]) if params[:movement_type].present?
    scope = scope.where("delivery_date >= ?", params[:from]) if params[:from].present?
    scope = scope.where("delivery_date <= ?", params[:to])   if params[:to].present?

    @movements = scope.limit(300)
    @showrooms = Showroom.active.order(:name)
    @products  = Product.where(active: true).order(:name)

    @filter = {
      showroom_id:   params[:showroom_id],
      product_id:    params[:product_id],
      movement_type: params[:movement_type],
      from:          params[:from],
      to:            params[:to]
    }
  end

  def quick_create_product
    product = Product.new(quick_product_params.merge(active: true))
    if product.save
      render json: { id: product.id, name: product.name }
    else
      render json: { error: product.errors.full_messages.first }, status: :unprocessable_entity
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

  # raw = { [product_id, showroom_id, movement_type] => qty }
  # Returns [stock_hash, product_ids]
  # stock_hash = { [product_id, showroom_id] => net_quantity }
  def build_stock_table(raw)
    stock = Hash.new(0)
    raw.each do |(product_id, showroom_id, movement_type), qty|
      factor = movement_type.in?(%w[entry initial]) ? 1 : -1
      stock[[product_id, showroom_id]] += factor * qty
    end
    product_ids = stock.keys.map(&:first).uniq
    [stock, product_ids]
  end

  def parse_initial_stock_items
    return [] unless params[:items].is_a?(ActionController::Parameters)
    params[:items].values
      .map { |i| i.permit(:product_id, :quantity).to_h.symbolize_keys }
      .reject { |i| i[:product_id].blank? || i[:quantity].blank? }
  end

  def quick_product_params
    params.require(:product).permit(:name, :base_code, :family_id)
  end
end
