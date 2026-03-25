# app/models/procurement_requirement.rb
class ProcurementRequirement < ApplicationRecord
  belongs_to :supplier_item
  belongs_to :purchase_order_item, optional: true

  STATUSES = %w[pending in_draft ordered cancelled].freeze

  validates :origin_order_number, presence: true
  validates :quantity, numericality: {greater_than: 0}
  validates :status, inclusion: {in: STATUSES}

  validates :supplier_item_id, uniqueness: {
    scope: :origin_order_number,
    message: "ya tiene un requerimiento para este pedido"
  }

  scope :pending, -> { where(status: "pending") }
  scope :in_draft, -> { where(status: "in_draft") }
  scope :ordered, -> { where(status: "ordered") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :active, -> { where(status: %w[pending in_draft]) }

  scope :for_purchase_order, ->(po) {
    where(purchase_order_item_id: po.purchase_order_items.pluck(:id))
  }

  def pending? = status == "pending"
  def in_draft? = status == "in_draft"
  def ordered? = status == "ordered"
  def cancelled? = status == "cancelled"

  def specs_summary
    return "" if specifications.blank?
    specifications.map { |k, v| "#{k}: #{v}" }.join(" | ")
  end

  # El purchase_order_item ya está vinculado al requirement antes de llamar esto.
  # Solo actualizamos el status.
  def mark_as_ordered!
    update!(status: "ordered")
  end

  def release!
    update!(status: "pending", purchase_order_item: nil)
  end
end
