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
    adapter = ActiveRecord::Base.connection.adapter_name

    if adapter == "SQLite"
      last_num = PurchaseOrder
        .where("number LIKE 'OC-%'")
        .pluck(:number)
        .map { |n| n.gsub(/[^0-9]/, "").to_i }
        .max
        .to_i

      "OC-#{(last_num + 1).to_s.rjust(4, "0")}"

    else
      PurchaseOrder.with_advisory_lock("generate_po_number") do
        last_num = PurchaseOrder
          .where("number ~ ?", "^OC-[0-9]+$")
          .maximum(Arel.sql("CAST(REGEXP_REPLACE(number, '[^0-9]', '', 'g') AS INTEGER)"))
          .to_i

        "OC-#{(last_num + 1).to_s.rjust(4, "0")}"
      end
    end
  end
end
