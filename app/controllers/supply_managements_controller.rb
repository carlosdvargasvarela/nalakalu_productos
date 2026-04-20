# app/controllers/supply_managements_controller.rb
class SupplyManagementsController < ApplicationController
  before_action :authenticate_user!

  def index
    @from = params[:from] || Date.current.beginning_of_week.to_s
    @to = params[:to] || Date.current.end_of_week.to_s

    @deliveries = LogisticsApiClient.fetch_deliveries(from: @from, to: @to)
    order_numbers = @deliveries.map { |d| d["order_number"] }

    # ── Requerimientos pendientes agrupados por proveedor ─────────────────
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

    # ── Órdenes existentes relacionadas al rango ──────────────────────────
    linked_po_item_ids = ProcurementRequirement
      .where(origin_order_number: order_numbers)
      .where.not(purchase_order_item_id: nil)
      .pluck(:purchase_order_item_id)

    @existing_orders = PurchaseOrder
      .joins(:purchase_order_items)
      .where(purchase_order_items: {id: linked_po_item_ids})
      .includes(:provider, purchase_order_items: :supplier_item)
      .distinct
      .order(created_at: :desc)

    # ── Statuses por número de orden ──────────────────────────────────────
    @requirement_statuses_by_order = ProcurementRequirement
      .where(origin_order_number: order_numbers)
      .pluck(:origin_order_number, :status)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }

    # ── Presenter para la vista de Trazabilidad ───────────────────────────
    @presenter = ProcurementPresenter.new(
      deliveries: @deliveries,
      supply_rules: SupplyRule.includes(:supplier_item, :variant, :variant_type)
    )

    ProductDecoder.clear_cache!
    ProcurementResolver.clear_cache!
  end

  # ── SYNC ALL → Sidekiq ───────────────────────────────────────────────────
  def sync_all
    from = params[:from] || Date.current.beginning_of_week.to_s
    to = params[:to] || Date.current.end_of_week.to_s

    SyncDeliveriesJob.perform_later(from: from, to: to, user_id: current_user.id)

    redirect_to supply_managements_path(from: from, to: to),
      notice: "Sincronización iniciada en segundo plano. Refresca en unos segundos."
  end

  # ── SYNC DELIVERY individual → síncrono (1 entrega = rápido) ────────────
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

  # ── CREATE PURCHASE ORDER ────────────────────────────────────────────────
  def create_purchase_order
    provider = Provider.find(params[:provider_id])
    requirement_ids = params[:requirement_ids]
    unit_costs = params[:unit_costs] || {}

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
        .group_by { |r| ProcurementConsolidator.grouping_key(r) }
        .each do |_key, reqs|
          first_req = reqs.first
          normalized_specs = ProcurementConsolidator.normalize_specs(first_req.specifications)

          entered_cost = reqs.map { |r| unit_costs[r.id.to_s].presence }.compact.first
          resolved_cost = parse_cost(entered_cost)
          resolved_cost = first_req.supplier_item.default_cost&.to_f || 0 if resolved_cost.nil? || resolved_cost.zero?

          po_item = purchase_order.purchase_order_items.create!(
            supplier_item_id: first_req.supplier_item_id,
            quantity: reqs.sum(&:quantity),
            unit_cost: resolved_cost,
            specifications: normalized_specs,
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

  private

  def parse_cost(raw)
    return nil if raw.blank?
    raw.gsub(/[^\d,.]/, "").delete(".").tr(",", ".").to_f
  end
end
