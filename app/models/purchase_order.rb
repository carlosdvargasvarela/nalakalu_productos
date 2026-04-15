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

  def as_pdf
    items = purchase_order_items
      .includes(:supplier_item, :procurement_requirements)
      .order(:id)

    PurchaseOrderPdf.new(self, items).render
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
