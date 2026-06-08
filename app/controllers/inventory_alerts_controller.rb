# app/controllers/inventory_alerts_controller.rb
class InventoryAlertsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_alert, only: [:resolve]

  def index
    @alerts = InventoryMovement.flagged
      .includes(:product, :showroom)
      .order(created_at: :desc)
  end

  def resolve
    note = build_resolution_note
    adjustment = create_adjustment! if create_adjustment?

    note = "Resuelta registrando ajuste de stock ##{adjustment.id} por #{adjustment.quantity} unidad(es). #{note}".strip if adjustment

    @alert.update!(
      flag: nil,
      notes: [@alert.notes.presence, "[Resolución] #{note}".strip].compact.join("\n\n")
    )

    redirect_to inventory_alerts_path, notice: "Alerta resuelta y trazabilidad registrada."
  end

  private

  def set_alert
    @alert = InventoryMovement.find(params[:id])
  end

  def resolution_params
    params.permit(:create_adjustment, :adjustment_quantity, :note)
  end

  def create_adjustment?
    resolution_params[:create_adjustment] == "1" && resolution_params[:adjustment_quantity].present?
  end

  def create_adjustment!
    InventoryMovement.create!(
      movement_type: "initial", source: "manual", status: "resolved",
      product_id: @alert.product_id, showroom_id: @alert.showroom_id,
      quantity: resolution_params[:adjustment_quantity], delivery_date: Date.current,
      notes: "Ajuste de corrección para la alerta ##{@alert.id} (#{@alert.product&.name} · #{@alert.showroom&.name})."
    )
  end

  def build_resolution_note
    resolution_params[:note].presence || "Resuelta manualmente sin ajuste de stock."
  end
end
