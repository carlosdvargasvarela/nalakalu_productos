class Inventory::InitialStockController < Inventory::BaseController
  def new
    @products  = Product.where(active: true).order(:name)
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
    @families  = Family.order(:name)
  end

  def create
    showroom_id    = params[:showroom_id].presence
    reference_date = params[:delivery_date].presence || Date.current.to_s
    notes          = params[:notes].presence
    items          = parse_initial_stock_items

    return redirect_to new_inventory_initial_stock_path, alert: "Debes seleccionar una sala." unless showroom_id
    return redirect_to new_inventory_initial_stock_path, alert: "Agrega al menos un producto con cantidad." if items.empty?

    saved  = []
    errors = []
    items.each do |item|
      m = InventoryMovement.new(
        movement_type: "initial", source: "manual", status: "resolved",
        showroom_id: showroom_id, product_id: item[:product_id],
        quantity: item[:quantity], delivery_date: reference_date, notes: notes
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

  def quick_product
    product = Product.new(quick_product_params.merge(active: true))
    if product.save
      render json: { id: product.id, name: product.name }
    else
      render json: { error: product.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  private

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
