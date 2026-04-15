class PurchaseOrderMailer < ApplicationMailer
  default from: ENV["MAIL_USERNAME"]

  def send_to_provider(purchase_order)
    @po = purchase_order
    @items = purchase_order.purchase_order_items
      .includes(:supplier_item, :procurement_requirements)
      .order(:id)

    pdf = PurchaseOrderPdf.new(@po, @items).render

    attachments["OC-#{@po.number}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf
    }

    mail(
      to: @po.provider.email,
      subject: "Orden de Compra #{@po.number} — Nalakalú"
    )
  end
end
