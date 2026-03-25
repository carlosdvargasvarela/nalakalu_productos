class SupplyManagementsController < ApplicationController
  def index
    # Filtros básicos por fecha de creación del requerimiento
    @start_date = params[:start_date].presence || Date.today.beginning_of_month
    @end_date = params[:end_date].presence || Date.today

    # Obtenemos requerimientos pendientes agrupados por Proveedor
    # Incluimos supplier_item y provider para evitar N+1
    @pending_requirements = ProcurementRequirement.pending
      .joins(supplier_item: :provider)
      .where(created_at: @start_date.to_date.beginning_of_day..@end_date.to_date.end_of_day)
      .includes(supplier_item: :provider)
      .order("providers.name ASC, supplier_items.name ASC")

    # Agrupamos en memoria para la vista
    @grouped_requirements = @pending_requirements.group_by { |req| req.supplier_item.provider }
  end

  def create_purchase_order
    provider = Provider.find(params[:provider_id])
    requirement_ids = params[:requirement_ids]

    if requirement_ids.blank?
      return redirect_to supply_managements_path, alert: "Debe seleccionar al menos un ítem."
    end

    ActiveRecord::Base.transaction do
      # 1. Crear la Orden de Compra (OC)
      @purchase_order = PurchaseOrder.create!(
        provider: provider,
        status: "borrador",
        issued_date: Date.today,
        number: "OC-#{Time.now.to_i}" # O tu lógica de numeración
      )

      # 2. Agrupar requerimientos por SupplierItem + Specifications para consolidar líneas de OC
      requirements = ProcurementRequirement.where(id: requirement_ids)

      # Agrupamos por [item_id, specs] para que si dos pedidos piden lo mismo, sea una sola línea en la OC
      requirements.group_by { |r| [r.supplier_item_id, r.specifications] }.each do |key, reqs|
        item_id, specs = key
        total_qty = reqs.sum(&:quantity)
        first_req = reqs.first

        # Crear la línea de la OC
        po_item = @purchase_order.purchase_order_items.create!(
          supplier_item_id: item_id,
          quantity: total_qty,
          unit: first_req.supplier_item.unit,
          unit_cost: first_req.supplier_item.default_cost || 0,
          specifications: specs
        )

        # Marcar requerimientos como procesados
        reqs.each { |r| r.mark_as_ordered!(po_item) }
      end
    end

    redirect_to purchase_order_path(@purchase_order), notice: "Orden de Compra creada exitosamente."
  rescue => e
    redirect_to supply_managements_path, alert: "Error al crear OC: #{e.message}"
  end
end
