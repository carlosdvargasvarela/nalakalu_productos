class Inventory::StockController < Inventory::BaseController
  def showroom
    @showroom  = Showroom.find(params[:showroom_id])
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)

    raw = InventoryMovement.stock_by_showroom(@showroom.id)

    @stock = Hash.new(0)
    raw.each do |(product_id, movement_type), qty|
      @stock[product_id] += movement_type.in?(%w[entry initial]) ? qty : -qty
    end
    @stock.reject! { |_, qty| qty.zero? }
    @products = Product.where(id: @stock.keys).order(:name).index_by(&:id)
  end
end
