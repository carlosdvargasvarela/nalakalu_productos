class ProcurementRequirement < ApplicationRecord
  belongs_to :supplier_item
  belongs_to :purchase_order_item, optional: true

  STATUSES = %w[pending in_draft ordered cancelled].freeze

  validates :origin_order_number, presence: true
  validates :quantity, numericality: {greater_than: 0}
  validates :status, inclusion: {in: STATUSES}

  # Evita duplicados: misma pieza para el mismo pedido
  validates :supplier_item_id, uniqueness: {
    scope: :origin_order_number,
    message: "ya tiene un requerimiento para este pedido"
  }

  scope :pending, -> { where(status: "pending") }
  scope :in_draft, -> { where(status: "in_draft") }
  scope :ordered, -> { where(status: "ordered") }
  scope :active, -> { where(status: %w[pending in_draft]) }

  def pending? = status == "pending"
  def in_draft? = status == "in_draft"
  def ordered? = status == "ordered"

  def specs_summary
    return "" if specifications.blank?
    specifications.map { |k, v| "#{k}: #{v}" }.join(" | ")
  end

  def mark_as_ordered!(purchase_order_item)
    update!(
      status: "ordered",
      purchase_order_item: purchase_order_item
    )
  end
end
