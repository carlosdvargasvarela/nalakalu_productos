class Inventory::AlertsController < Inventory::BaseController
  before_action :set_alert, only: [:resolve]

  def index
    @alerts = InventoryMovement.flagged
      .includes(:product, :showroom)
      .order(created_at: :desc)
  end

  def bulk_resolve
    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    return redirect_to inventory_alerts_path, alert: "No seleccionaste ninguna alerta." if ids.empty?

    count = 0
    InventoryMovement.flagged.where(id: ids).each do |a|
      note = "[Resolución masiva #{Date.current.strftime('%d/%m/%Y')}]"
      a.update_columns(flag: nil, notes: [a.notes.presence, note].compact.join("\n\n"))
      count += 1
    end
    redirect_to inventory_alerts_path, notice: "#{count} alerta(s) resueltas."
  end

  def resolve
    note = params[:note].presence || "Resuelta manualmente sin ajuste de stock."
    adjustment = nil

    if params[:create_adjustment] == "1" && params[:adjustment_quantity].present?
      adjustment = InventoryMovement.create!(
        movement_type: "initial", source: "manual", status: "resolved",
        product_id: @alert.product_id, showroom_id: @alert.showroom_id,
        quantity: params[:adjustment_quantity], delivery_date: Date.current,
        notes: "Ajuste de corrección para la alerta ##{@alert.id} (#{@alert.product&.name} · #{@alert.showroom&.name})."
      )
      note = "Resuelta registrando ajuste ##{adjustment.id} por #{adjustment.quantity} unidad(es). #{note}".strip
    end

    @alert.update!(
      flag: nil,
      notes: [@alert.notes.presence, "[Resolución] #{note}"].compact.join("\n\n")
    )
    redirect_to inventory_alerts_path, notice: "Alerta resuelta."
  end

  private

  def set_alert
    @alert = InventoryMovement.find(params[:id])
  end
end
