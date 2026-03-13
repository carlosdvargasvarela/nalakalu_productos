class PurchaseOrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_purchase_order, only: [:show, :edit, :update, :destroy]

  def index
    @purchase_orders = PurchaseOrder.includes(:provider).order(created_at: :desc)
  end

  def show
  end

  def edit
  end

  def update
    purchase_order_params_merged =
      if params[:commit] == "confirmar"
        purchase_order_params.merge(status: "confirmada")
      else
        purchase_order_params
      end

    if @purchase_order.update(purchase_order_params_merged)
      delivery_number = @purchase_order.notes.to_s.split("Generada desde Entrega: ").last

      respond_to do |format|
        format.turbo_stream do
          streams = [turbo_stream.replace("remote_modal", "")]

          # Si hay un frame de proveedor en la página, lo actualizamos
          if delivery_number.present?
            streams << turbo_stream.replace(
              "provider_card_#{@purchase_order.provider_id}",
              partial: "logistics_queries/provider_card",
              locals: {
                provider: @purchase_order.provider,
                variants: [],
                delivery_number: delivery_number
              }
            )
          end

          render turbo_stream: streams
        end
        format.html { redirect_to @purchase_order, notice: "Orden de Compra actualizada." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "remote_modal",
            partial: "purchase_orders/modal_edit",
            locals: {purchase_order: @purchase_order}
          )
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    provider_id = @purchase_order.provider_id
    delivery_number = @purchase_order.notes.to_s.split("Generada desde Entrega: ").last

    if current_user.role == "admin" || @purchase_order.status == "borrador"
      @purchase_order.destroy

      respond_to do |format|
        format.turbo_stream do
          streams = [
            turbo_stream.remove("purchase_order_#{provider_id}"),
            turbo_stream.replace("remote_modal", "")
          ]

          # Refrescamos la tarjeta del proveedor para que vuelva a mostrar el botón "Generar Borrador OC"
          if delivery_number.present?
            streams << turbo_stream.replace(
              "provider_card_#{provider_id}",
              partial: "logistics_queries/provider_card",
              locals: {
                provider: Provider.find(provider_id),
                variants: [],
                delivery_number: delivery_number
              }
            )
          end

          render turbo_stream: streams
        end
        format.html { redirect_to purchase_orders_path, notice: "Orden de Compra eliminada." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("remote_modal", "")
        end
        format.html do
          redirect_to purchase_orders_path,
            alert: "No tienes permiso para eliminar una orden confirmada."
        end
      end
    end
  end

  def create_from_delivery
    provider = Provider.find(params[:provider_id])
    items_data = params[:items] || {}

    @purchase_order = PurchaseOrder.new(
      provider: provider,
      notes: "Generada desde Entrega: #{params[:order_number]}",
      issued_date: Date.current,
      status: "borrador"
    )

    items_data.each do |_, data|
      variant = Variant.find_by(id: data[:variant_id])
      next unless variant

      pricing = variant.default_pricing

      @purchase_order.purchase_order_items.build(
        variant: variant,
        variant_pricing: pricing,
        quantity: data[:quantity].to_f,
        unit: pricing&.unit || "und",
        unit_cost: pricing&.cost || variant.cost || 0,
        description_override: data[:variant_name]
      )
    end

    if @purchase_order.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            # Abre el modal con el borrador listo para editar
            turbo_stream.replace(
              "remote_modal",
              partial: "purchase_orders/modal_edit",
              locals: {purchase_order: @purchase_order}
            ),
            # Actualiza la tarjeta del proveedor en el fondo (ya muestra "OC Generada")
            turbo_stream.replace(
              "provider_card_#{provider.id}",
              partial: "logistics_queries/provider_card",
              locals: {
                provider: provider,
                variants: items_data.values.map do |d|
                  {
                    variant_id: d[:variant_id],
                    quantity: d[:quantity],
                    variant_name: d[:variant_name],
                    variant_type: "",
                    product_name: d[:product_name].to_s
                  }
                end,
                delivery_number: params[:order_number]
              }
            )
          ]
        end
        format.html { redirect_to edit_purchase_order_path(@purchase_order) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("remote_modal", "")
        end
        format.html do
          redirect_back fallback_location: logistics_queries_path,
            alert: "Error al crear la OC: #{@purchase_order.errors.full_messages.to_sentence}"
        end
      end
    end
  end

  private

  def set_purchase_order
    @purchase_order = PurchaseOrder
      .includes(purchase_order_items: [:variant, :variant_pricing])
      .find(params[:id])
  end

  def purchase_order_params
    params.require(:purchase_order).permit(
      :delivery_deadline, :notes, :status,
      purchase_order_items_attributes: [
        :id, :variant_id, :variant_pricing_id,
        :quantity, :unit, :unit_cost,
        :description_override, :_destroy
      ]
    )
  end
end
