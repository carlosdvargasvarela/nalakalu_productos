class SupplyManagementsController < ApplicationController
  before_action :authenticate_user!

  def index
    @from = params[:from] || Date.current.beginning_of_week.to_s
    @to = params[:to] || Date.current.end_of_week.to_s
    @order_number = params[:order_number]
    @seller_code = params[:seller_code]

    # Entregas del API para sincronizar
    @deliveries = LogisticsApiClient.fetch_deliveries(
      from: @from,
      to: @to,
      order_number: @order_number,
      seller_code: @seller_code
    )

    # Requerimientos activos (pending + in_draft) agrupados por proveedor
    @grouped_requirements = ProcurementRequirement
      .active
      .joins(supplier_item: :provider)
      .includes(supplier_item: :provider)
      .order("providers.name ASC, supplier_items.name ASC")
      .group_by { |r| r.supplier_item.provider }
  end

  def sync_delivery
    delivery_id = params[:delivery_id]
    delivery = LogisticsApiClient.new.fetch_delivery(delivery_id)

    unless delivery
      return redirect_to supply_managements_path,
        alert: "No se pudo obtener la entrega #{delivery_id}."
    end

    results = ProcurementResolver.resolve_delivery(delivery)
    new_count = results.count(&:previously_new_record?)
    existing_count = results.size - new_count

    msg = "Entrega sincronizada: #{new_count} requerimientos nuevos"
    msg += ", #{existing_count} ya existían." if existing_count > 0

    redirect_to supply_managements_path, notice: msg
  rescue => e
    redirect_to supply_managements_path, alert: "Error al sincronizar: #{e.message}"
  end

  def create_purchase_order
    provider = Provider.find(params[:provider_id])
    requirement_ids = Array(params[:requirement_ids]).reject(&:blank?)

    if requirement_ids.blank?
      return redirect_to supply_managements_path,
        alert: "No hay requerimientos seleccionados para generar la orden."
    end

    ActiveRecord::Base.transaction do
      @purchase_order = PurchaseOrder.create!(
        provider: provider,
        issued_date: Date.current
      )

      requirements = ProcurementRequirement
        .where(id: requirement_ids, status: "pending")
        .joins(:supplier_item)
        .where(supplier_items: {provider_id: provider.id})
        .includes(:supplier_item)

      if requirements.empty?
        raise ActiveRecord::Rollback,
          "No se encontraron requerimientos pendientes válidos para este proveedor."
      end

      # Agrupar por pieza + specs para consolidar líneas de OC
      requirements.group_by { |r| [r.supplier_item_id, r.specifications.to_s] }.each do |(item_id, _specs_key), reqs|
        total_qty = reqs.sum(&:quantity)
        first_req = reqs.first
        specs = first_req.specifications

        po_item = @purchase_order.purchase_order_items.create!(
          supplier_item_id: item_id,
          quantity: total_qty,
          unit: first_req.supplier_item.unit,
          unit_cost: first_req.supplier_item.default_cost || 0,
          specifications: specs
        )

        reqs.each { |r| r.update!(status: "in_draft", purchase_order_item: po_item) }
      end
    end

    redirect_to purchase_order_path(@purchase_order),
      notice: "Orden #{@purchase_order.number} creada. Revísala antes de enviarla al proveedor."
  rescue ActiveRecord::Rollback => e
    redirect_to supply_managements_path,
      alert: e.message.presence || "Error al crear la OC."
  rescue => e
    redirect_to supply_managements_path, alert: "Error inesperado: #{e.message}"
  end
end
