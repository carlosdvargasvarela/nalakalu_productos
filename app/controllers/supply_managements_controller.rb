class SupplyManagementsController < ApplicationController
  before_action :authenticate_user!

  def index
    @from = params[:from] || Date.current.beginning_of_week.to_s
    @to = params[:to] || Date.current.end_of_week.to_s

    # Solo lee entregas para mostrar trazabilidad — NO resuelve ni escribe en DB.
    # El procesamiento ocurre únicamente en sync_all y sync_delivery.
    @deliveries = LogisticsApiClient.fetch_deliveries(from: @from, to: @to)

    order_numbers = @deliveries.map { |d| d["order_number"] }

    pending_reqs = ProcurementRequirement
      .where(status: "pending", origin_order_number: order_numbers)
      .includes(supplier_item: :provider)

    @grouped_data = pending_reqs
      .group_by { |r| r.supplier_item.provider }
      .sort_by { |provider, _| provider.name }
      .map do |provider, reqs|
        {
          provider: provider,
          consolidated_items: ProcurementConsolidator.consolidate(reqs)
        }
      end

    # El presenter necesita el cache del decoder para la vista de trazabilidad.
    # Se carga aquí solo para lectura, sin persistir nada.
    ProductDecoder.clear_cache!
    ProcurementResolver.clear_cache!

    @presenter = ProcurementPresenter.new(
      deliveries: @deliveries,
      supply_rules: SupplyRule.includes(:supplier_item).to_a
    )
  end

  # POST /supply_managements/sync_all
  def sync_all
    from = params[:from] || Date.current.beginning_of_week.to_s
    to = params[:to] || Date.current.end_of_week.to_s

    ProductDecoder.clear_cache!
    ProcurementResolver.clear_cache!

    deliveries = LogisticsApiClient.fetch_deliveries(from: from, to: to)
    results = deliveries.flat_map { |d| ProcurementResolver.resolve_delivery(d) }

    new_count = results.count(&:previously_new_record?)
    existing_count = results.size - new_count

    msg = "Sincronización completa: #{new_count} requerimientos nuevos"
    msg += ", #{existing_count} ya existían." if existing_count > 0

    redirect_to supply_managements_path(from: from, to: to), notice: msg
  rescue => e
    redirect_to supply_managements_path, alert: "Error al sincronizar: #{e.message}"
  end

  # POST /supply_managements/sync_delivery
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

  # POST /supply_managements/create_purchase_order
  def create_purchase_order
    provider = Provider.find(params[:provider_id])
    requirement_ids = params[:requirement_ids]

    if requirement_ids.blank?
      return redirect_to supply_managements_path,
        alert: "Debe seleccionar al menos un requerimiento."
    end

    requirements = ProcurementRequirement
      .where(id: requirement_ids, status: "pending")
      .includes(:supplier_item)

    if requirements.empty?
      return redirect_to supply_managements_path,
        alert: "Los requerimientos seleccionados ya no están disponibles."
    end

    purchase_order = nil

    ActiveRecord::Base.transaction do
      purchase_order = PurchaseOrder.create!(
        provider: provider,
        status: "borrador",
        issued_date: Date.current
      )

      requirements
        .group_by { |r| [r.supplier_item_id, r.specifications.sort.to_h] }
        .each do |(item_id, _specs), reqs|
          first_req = reqs.first

          po_item = purchase_order.purchase_order_items.create!(
            supplier_item_id: item_id,
            quantity: reqs.sum(&:quantity),
            unit_cost: first_req.supplier_item.default_cost || 0,
            specifications: first_req.specifications,
            description_override: first_req.supplier_item.name
          )

          reqs.each { |r| r.update!(purchase_order_item_id: po_item.id, status: "in_draft") }
        end
    end

    redirect_to edit_purchase_order_path(purchase_order),
      notice: "OC #{purchase_order.number} creada. Revise costos antes de enviar."
  rescue => e
    redirect_to supply_managements_path,
      alert: "Error al crear la orden: #{e.message}"
  end
end
