# app/controllers/supply_managements_controller.rb
class SupplyManagementsController < ApplicationController
  before_action :authenticate_user!

  def index
    @from = params[:from] || Date.current.beginning_of_week.to_s
    @to = params[:to] || Date.current.end_of_week.to_s

    ProductDecoder.clear_cache!
    ProcurementResolver.clear_cache!

    @deliveries = LogisticsApiClient.fetch_deliveries(from: @from, to: @to)
    @deliveries.each { |d| ProcurementResolver.resolve_delivery(d) }

    order_numbers = @deliveries.map { |d| d["order_number"] }

    pending_reqs = ProcurementRequirement
      .where(status: "pending", origin_order_number: order_numbers)
      .includes(supplier_item: :provider)

    @grouped_data = pending_reqs
      .group_by { |r| r.supplier_item.provider }
      .map do |provider, reqs|
        {
          provider: provider,
          consolidated_items: ProcurementConsolidator.consolidate(reqs)
        }
      end

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

    @purchase_order = nil

    ActiveRecord::Base.transaction do
      @purchase_order = PurchaseOrder.create!(
        provider: provider,
        status: "borrador",
        issued_date: Date.current
      )

      requirements
        .group_by { |r| [r.supplier_item_id, r.specifications.to_s] }
        .each do |(item_id, _specs), reqs|
          first_req = reqs.first

          po_item = @purchase_order.purchase_order_items.create!(
            supplier_item_id: item_id,
            quantity: reqs.sum(&:quantity),
            unit: first_req.supplier_item.unit,
            unit_cost: first_req.supplier_item.default_cost || 0,
            specifications: first_req.specifications,
            description_override: first_req.supplier_item.name
          )

          reqs.each do |r|
            r.update!(
              purchase_order_item_id: po_item.id,
              status: "in_draft"
            )
          end
        end
    end

    redirect_to edit_purchase_order_path(@purchase_order),
      notice: "OC #{@purchase_order.number} creada como borrador. Revise costos y cantidades antes de enviar."
  rescue => e
    redirect_to supply_managements_path,
      alert: "Error al crear la orden: #{e.message}"
  end
end
