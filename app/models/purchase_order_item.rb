class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :supplier_item

  has_many :procurement_requirements, dependent: :nullify

  validates :quantity, presence: true, numericality: {greater_than: 0}
  validates :unit_cost, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :supplier_item, presence: true

  def total
    (quantity || 0).to_d * (unit_cost || 0).to_d
  end

  def unit
    self[:unit].presence || supplier_item&.unit
  end

  def specs_summary
    return "" if specifications.blank?
    Array(specifications).map { |s|
      "#{s["label"] || s[:label]}: #{s["value"] || s[:value]}"
    }.join(" | ")
  end

  def line_description
    base = description_override.presence || supplier_item&.name || "Sin descripción"
    specs_summary.present? ? "#{base} | #{specs_summary}" : base
  end
end
