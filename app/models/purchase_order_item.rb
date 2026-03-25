class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :variant, optional: true       # Mantenemos por compatibilidad
  belongs_to :supplier_item, optional: true # El nuevo campo principal

  has_many :procurement_requirements, dependent: :nullify

  validates :quantity, :unit, :unit_cost, presence: true
  validate :must_have_variant_or_supplier_item

  def total
    (quantity || 0) * (unit_cost || 0)
  end

  def specs_summary
    return "" if specifications.blank?
    specifications.map { |k, v| "#{k}: #{v}" }.join(" | ")
  end

  def line_description
    base = supplier_item&.name || variant&.name || description_override || "Sin descripción"
    specs_summary.present? ? "#{base} | #{specs_summary}" : base
  end

  private

  def must_have_variant_or_supplier_item
    if variant_id.blank? && supplier_item_id.blank?
      errors.add(:base, "debe tener una variante o una pieza de proveedor")
    end
  end
end
