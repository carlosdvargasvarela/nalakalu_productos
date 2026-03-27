class ProcurementRequirement < ApplicationRecord
  belongs_to :supplier_item
  belongs_to :purchase_order_item, optional: true
  belongs_to :supply_rule, optional: true

  STATUSES = %w[pending in_draft ordered received cancelled].freeze

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

  def pending?
    status == "pending"
  end

  def in_draft?
    status == "in_draft"
  end

  def ordered?
    status == "ordered"
  end

  def cancelled?
    status == "cancelled"
  end

  def specs_summary
    return "" if specifications.blank?
    specifications.map { |k, v| "#{k}: #{v}" }.join(" | ")
  end

  def mark_as_ordered!
    update!(status: "ordered")
  end

  def release!
    update!(status: "pending", purchase_order_item_id: nil)
  end

  def add_quantity!(extra_qty, new_specs = {})
    self.quantity += extra_qty.to_f
    self.specifications = (specifications || {}).merge(new_specs) if new_specs.present?
    save!
  end
end
