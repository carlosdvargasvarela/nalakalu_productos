# app/controllers/logistics_queries_controller.rb
class LogisticsQueriesController < ApplicationController
  before_action :authenticate_user!

  def index
    @from = params[:from] || Date.current.beginning_of_week.to_s
    @to = params[:to] || Date.current.end_of_week.to_s
    @order_number = params[:order_number]
    @seller_code = params[:seller_code]

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
      @decoded_items = decode_delivery_items(@delivery["items"])
    else
      redirect_to logistics_queries_path,
        alert: "No se pudo encontrar el detalle de la entrega."
    end
  end

  private

  # Decodifica cada ítem de la entrega para mostrar producto y variantes detectadas.
  # Ya no agrupa por proveedor (esa lógica vive en supply_managements).
  def decode_delivery_items(items)
    items.map do |item|
      decoding = ProductDecoder.decode(item["product_name"])

      {
        raw: item,
        product_name: item["product_name"],
        quantity: item["quantity_delivered"],
        has_variants: decoding.has_variants,
        base_product: decoding.base_product,
        variants: decoding.variants,
        unrecognized: decoding.unrecognized_codes
      }
    end
  end
end
