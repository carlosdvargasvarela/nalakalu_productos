class SupplyRuleQuantity < ApplicationRecord
  belongs_to :supply_rule
  belongs_to :product

  validates :quantity_needed, numericality: {greater_than: 0}
  validates :product_id, uniqueness: {
    scope: :supply_rule_id,
    message: "ya tiene una cantidad configurada para esta regla"
  }
end
