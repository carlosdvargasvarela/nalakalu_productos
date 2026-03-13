# app/models/purchase_order_item.rb
class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :variant
  belongs_to :variant_pricing, optional: true

  validates :quantity, :unit, :unit_cost, presence: true

  def total
    (quantity || 0) * (unit_cost || 0)
  end
end
