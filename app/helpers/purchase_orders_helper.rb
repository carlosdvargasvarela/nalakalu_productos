# app/helpers/purchase_orders_helper.rb
module PurchaseOrdersHelper
  TRANSITIONS = {
    "borrador" => [
      {label: "Marcar como Enviado", next: "enviado", style: "btn-primary", icon: "bi-send-fill"}
    ],
    "enviado" => [
      {label: "Confirmar con Proveedor", next: "confirmado", style: "btn-success", icon: "bi-check-circle-fill"},
      {label: "Cancelar Orden", next: "cancelado", style: "btn-outline-danger", icon: "bi-x-circle"}
    ],
    "confirmado" => [
      {label: "Marcar como Recibido", next: "recibido", style: "btn-success", icon: "bi-box-seam-fill"},
      {label: "Cancelar Orden", next: "cancelado", style: "btn-outline-danger", icon: "bi-x-circle"}
    ],
    "recibido" => [],
    "cancelado" => [
      {label: "Reabrir como Borrador", next: "borrador", style: "btn-outline-secondary", icon: "bi-arrow-counterclockwise"}
    ]
  }.freeze

  def transitions_for(purchase_order)
    TRANSITIONS.fetch(purchase_order.status, [])
  end
end
