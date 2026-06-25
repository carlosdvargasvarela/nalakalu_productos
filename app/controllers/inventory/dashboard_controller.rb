class Inventory::DashboardController < Inventory::BaseController
  def index
    @pending_syncs = InventorySync.pending.ordered
    @recent_syncs  = InventorySync.confirmed.ordered.limit(5)

    raw = InventoryMovement.stock_by_product_and_showroom
    @stock, @product_ids = build_stock_table(raw)
    @products  = Product.where(id: @product_ids).order(:name).index_by(&:id)
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
    @flagged_count = InventoryMovement.flagged.count

    sync_config = InventorySyncConfig.current
    @from = params[:from] || sync_config.default_from_date.to_s
    @to   = params[:to]   || sync_config.default_to_date.to_s

    @kpi_products = @products.count { |pid, _| @showrooms.any? { |s| @stock[[pid, s.id]].to_i > 0 } }
    @kpi_no_stock = @products.count { |pid, _| @showrooms.sum { |s| @stock[[pid, s.id]].to_i } <= 0 }
    @kpi_units    = @stock.values.sum.round(2)

    respond_to do |format|
      format.html
      format.csv do
        send_data generate_stock_csv,
          filename: "stock_inventario_#{Date.current.iso8601}.csv",
          type: "text/csv; charset=utf-8"
      end
    end
  end

  def sync
    from = params[:from] || Date.current.beginning_of_week.to_s
    to   = params[:to]   || Date.current.end_of_week.to_s

    overlapping = InventorySync.pending_logistics_sync_overlapping(from, to)
    if overlapping
      return redirect_to inventory_sync_path(overlapping), alert:
        "Ya hay una sincronización pendiente de revisión (#{overlapping.from_date.strftime('%d/%m/%Y')}–" \
        "#{overlapping.to_date.strftime('%d/%m/%Y')}) que se superpone con este rango. " \
        "Confírmala o elimínala antes de volver a sincronizar."
    end

    SyncInventoryJob.perform_later(from: from, to: to, user_id: current_user.id)
    redirect_to inventory_path, notice: "Sincronización iniciada. Refresca en unos segundos."
  end

  def product_movements
    @product = Product.find(params[:product_id])
    @movements = InventoryMovement
      .confirmed_only.resolved
      .where(product_id: @product.id)
      .order(delivery_date: :desc, created_at: :desc)
      .limit(50)
    render partial: "inventory/dashboard/product_movements_modal",
           locals: { product: @product, movements: @movements }
  end

  private

  def generate_stock_csv
    require "csv"
    CSV.generate(encoding: "UTF-8") do |csv|
      csv << ["Producto"] + @showrooms.map(&:name) + ["Total"]
      @products.each_value do |product|
        total = 0
        row   = [product.name]
        @showrooms.each do |s|
          qty = @stock[[product.id, s.id]].to_i
          total += qty
          row << qty
        end
        csv << row + [total]
      end
    end
  end

  def build_stock_table(raw)
    stock = Hash.new(0)
    raw.each do |(product_id, showroom_id, movement_type), qty|
      factor = movement_type.in?(%w[entry initial]) ? 1 : -1
      stock[[product_id, showroom_id]] += factor * qty
    end
    product_ids = stock.keys.map(&:first).uniq
    [stock, product_ids]
  end
end
