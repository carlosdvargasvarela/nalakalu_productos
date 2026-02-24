# app/controllers/logistics_queries_controller.rb
class LogisticsQueriesController < ApplicationController
  before_action :authenticate_user!

  def index
    @from = params[:from] || Date.current.beginning_of_week.to_s
    @to = params[:to] || Date.current.end_of_week.to_s
    @order_number = params[:order_number]
    @seller_code = params[:seller_code]

    # Solo consultamos si hay parámetros de búsqueda o es la carga inicial
    @deliveries = LogisticsApiClient.fetch_deliveries({
      from: @from,
      to: @to,
      order_number: @order_number,
      seller_code: @seller_code
    })
  end

  def show
    @delivery = LogisticsApiClient.new.fetch_delivery(params[:id])

    if @delivery
      # Pre-procesamos todos los items para agrupar por proveedor
      # Esto facilita la vida al bodeguero
      @items_by_provider = group_items_by_provider(@delivery["items"])
    else
      redirect_to logistics_queries_path, alert: "No se pudo encontrar el detalle de la entrega."
    end
  end

  private

  def group_items_by_provider(items)
    grouped = Hash.new { |h, k| h[k] = [] }

    items.each do |item|
      decoding = ProductDecoder.decode(item["product_name"])
      if decoding[:has_variants]
        decoding[:variants].each do |variant|
          grouped[variant.provider] << {
            product_name: item["product_name"],
            variant_name: variant.name,
            variant_type: variant.variant_type.name,
            quantity: item["quantity_delivered"]
          }
        end
      end
    end
    grouped
  end
end
