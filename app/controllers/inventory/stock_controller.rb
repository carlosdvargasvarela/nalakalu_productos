class Inventory::StockController < Inventory::BaseController
  def showroom
    @showroom  = Showroom.find(params[:showroom_id])
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)

    raw = InventoryMovement
      .confirmed_only.resolved
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
end
