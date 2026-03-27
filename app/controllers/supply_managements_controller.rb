class SupplyManagementsController < ApplicationController
  before_action :authenticate_user!
  def index
    @from = params[:from] || Date.current.beginning_of_week.to_s
    @to = params[:to] || Date.current.end_of_week.to_s

    # 1. Limpieza y Sincronización
    ProductDecoder.clear_cache!
    ProcurementResolver.clear_cache!
    @deliveries = LogisticsApiClient.fetch_deliveries(from: @from, to: @to)

    # 2. Procesar (Esto asegura que los ProcurementRequirement existan en DB)
    @deliveries.each { |d| ProcurementResolver.resolve_delivery(d) }

    # 3. Obtener requerimientos pendientes de estos pedidos
    order_numbers = @deliveries.map { |d| d["order_number"] }
    pending_reqs = ProcurementRequirement.pending
      .includes(supplier_item: :provider)
      .where(origin_order_number: order_numbers)

    # 4. Consolidación para la "Mesa de Compras"
    @grouped_data = pending_reqs.group_by { |r| r.supplier_item.provider }.map do |provider, reqs|
      {
        provider: provider,
        consolidated_items: ProcurementConsolidator.consolidate(reqs)
      }
    end

    # 5. Presenter para la pestaña de "Trazabilidad" (tu vista de Logistics)
    @presenter = ProcurementPresenter.new(
      deliveries: @deliveries,
      supply_rules: SupplyRule.includes(:supplier_item).to_a
    )
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
