# app/models/purchase_order.rb
class PurchaseOrder < ApplicationRecord
  belongs_to :provider
  has_many :purchase_order_items, dependent: :destroy
  # Importante: permitir destruir ítems desde el formulario
  accepts_nested_attributes_for :purchase_order_items, allow_destroy: true

  STATUSES = %w[borrador enviado confirmado recibido cancelado].freeze

  validates :number, presence: true, uniqueness: true
  validates :status, inclusion: {in: STATUSES}

  before_validation :set_defaults, on: :create

  def total_amount
    # Usamos decimal para evitar errores de redondeo de punto flotante
    purchase_order_items.reject(&:marked_for_destruction?).sum(&:total)
  end

  def mailto_url
    subject = "Orden de Compra #{number} - Nalakalú Solutions"
    # Formateamos el total con moneda
    formatted_total = ActionController::Base.helpers.number_to_currency(total_amount, unit: "₡", delimiter: ".", separator: ",")

    body = "Estimados #{provider.name},\n\n" \
           "Adjunto enviamos la Orden de Compra #{number} " \
           "por un total de #{formatted_total}.\n\n" \
           "Favor confirmar recepción y fecha estimada de entrega.\n\n" \
           "Saludos cordiales,\nNalakalú Solutions S.A."

    "mailto:#{provider.email}?subject=#{ERB::Util.url_encode(subject)}&body=#{ERB::Util.url_encode(body)}"
  end

  private

  def set_defaults
    self.status ||= "borrador"
    self.issued_date ||= Date.current
    self.number ||= generate_number
  end

  def generate_number
    # Buscamos el número más alto extrayendo solo los dígitos
    last_order = PurchaseOrder.order(id: :desc).first
    last_num = last_order ? last_order.number.gsub(/\D/, "").to_i : 0
    "OC-#{(last_num + 1).to_s.rjust(4, "0")}"
  end
end
