# app/controllers/purchase_orders_controller.rb
class PurchaseOrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_purchase_order, only: %i[show edit update destroy transition]

  ALLOWED_TRANSITIONS = {
    "borrador" => %w[enviado cancelado],
    "enviado" => %w[confirmado cancelado],
    "confirmado" => %w[recibido cancelado],
    "recibido" => [],
    "cancelado" => %w[borrador]
  }.freeze

  def index
    @purchase_orders = PurchaseOrder
      .includes(:provider, :purchase_order_items)
      .order(created_at: :desc)

    @purchase_orders = @purchase_orders.where(status: params[:status]) if params[:status].present?
    @purchase_orders = @purchase_orders.where(provider_id: params[:provider_id]) if params[:provider_id].present?

    @providers = Provider.where(active: true).order(:name)
    @statuses = PurchaseOrder::STATUSES
  end

  def show
    @items = po_items_for_display(@purchase_order)
  end

  def edit
    @items = po_items_for_display(@purchase_order)
  end

  def update
    if @purchase_order.update(purchase_order_params)
      redirect_to @purchase_order, notice: "Orden de Compra actualizada."
    else
      @items = po_items_for_display(@purchase_order)
      render :edit, status: :unprocessable_entity
    end
  end

  # PDF con Tempfile → no acumula el binario en RAM del proceso web
  def download_pdf
    po = PurchaseOrder.find(params[:id])
    items = po_items_for_display(po)

    Tempfile.create(["oc_#{po.number}", ".pdf"], binmode: true) do |f|
      f.write(PurchaseOrderPdf.new(po, items).render)
      f.rewind
      send_file f.path,
        filename: "OC-#{po.number}.pdf",
        type: "application/pdf",
        disposition: "attachment"
    end
  end

  def send_by_email
    @purchase_order = PurchaseOrder.find(params[:id])
    recipient = params[:recipient_email].presence || @purchase_order.provider.email

    if recipient.blank?
      return redirect_to purchase_order_path(@purchase_order),
        alert: "El proveedor no tiene un correo configurado."
    end

    unless current_user.outlook_connected?
      return redirect_to purchase_order_path(@purchase_order),
        alert: "Tu cuenta de Outlook no está conectada. Ve a tu perfil para vincularla."
    end

    begin
      mailer = MicrosoftGraphMailer.new(current_user)
      extra_attachments = Array(params[:attachments])

      if mailer.send_purchase_order(@purchase_order, recipient,
        extra_attachments: extra_attachments,
        note: params[:note])
        @purchase_order.update(status: "enviado")
        flash[:notice] = "Orden enviada correctamente a #{recipient}."
      end
    rescue => e
      Rails.logger.error "MAILER ERROR (PO ##{@purchase_order.id}): #{e.message}"
      flash[:alert] = e.message
    end

    redirect_to purchase_order_path(@purchase_order)
  end

  def transition
    next_status = params[:transition]
    allowed = ALLOWED_TRANSITIONS[@purchase_order.status] || []

    unless allowed.include?(next_status)
      return redirect_to @purchase_order,
        alert: "Transición no permitida: #{@purchase_order.status} → #{next_status}."
    end

    ActiveRecord::Base.transaction do
      @purchase_order.update!(status: next_status)

      case next_status
      when "enviado"
        ProcurementRequirement.for_purchase_order(@purchase_order).update_all(status: "ordered")
      when "cancelado"
        ProcurementRequirement.for_purchase_order(@purchase_order)
          .update_all(status: "pending", purchase_order_item_id: nil)
      end
    end

    redirect_to @purchase_order, notice: "Estado actualizado a: #{next_status}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @purchase_order, alert: "Error: #{e.message}"
  end

  def destroy
    unless current_user.role == "admin" || @purchase_order.status == "borrador"
      return redirect_to purchase_orders_path,
        alert: "Solo se pueden eliminar órdenes en borrador."
    end

    # update_all evita instanciar cada requirement
    ProcurementRequirement.for_purchase_order(@purchase_order)
      .update_all(status: "pending", purchase_order_item_id: nil)

    @purchase_order.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("purchase_order_#{@purchase_order.id}"),
          turbo_stream.prepend("flash_container",
            partial: "shared/flash",
            locals: {type: "success", message: "Orden eliminada correctamente."})
        ]
      end
      format.html { redirect_to purchase_orders_path, notice: "Orden eliminada." }
    end
  end

  def origin_order_detail
    @purchase_order = PurchaseOrder.find(params[:id])
    @order_number = params[:order_number]

    po_item_ids = @purchase_order.purchase_order_items.pluck(:id)

    @requirements = ProcurementRequirement
      .where(purchase_order_item_id: po_item_ids, origin_order_number: @order_number)
      .includes(:supplier_item, supply_rule: [:product, {variant: :variant_type}])

    render partial: "purchase_orders/origin_order_modal",
      locals: {order_number: @order_number, requirements: @requirements}
  end

  private

  def set_purchase_order
    @purchase_order = PurchaseOrder
      .includes(purchase_order_items: [:supplier_item, :procurement_requirements])
      .find(params[:id])
  end

  # Query reutilizable para show/edit/update — sin procurement_requirements
  # en contextos donde no se necesitan (ej: edit de costos)
  def po_items_for_display(po)
    po.purchase_order_items
      .includes(:supplier_item, :procurement_requirements)
      .order(:id)
  end

  def purchase_order_params
    params.require(:purchase_order).permit(
      :delivery_deadline, :notes,
      purchase_order_items_attributes: [
        :id, :quantity, :unit_cost, :description_override, :_destroy
      ]
    )
  end
end
