# app/models/purchase_order_item.rb
class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :variant, optional: true
  belongs_to :supplier_item, optional: true

  # Importante: nullify para que si borras el ítem de la OC,
  # el requerimiento vuelva a quedar "huérfano" pero no se borre.
  has_many :procurement_requirements, dependent: :nullify

  validates :quantity, :unit, :unit_cost, presence: true
  validate :must_have_variant_or_supplier_item

  def total
    (quantity || 0).to_d * (unit_cost || 0).to_d
  end

  def specs_summary
    return "" if specifications.blank?
    # specifications es un JSONB, lo recorremos
    specifications.map { |k, v| "#{k}: #{v}" }.join(" | ")
  end

  def line_description
    # Prioridad: Override > Supplier Item > Variant
    base = description_override.presence || supplier_item&.name || variant&.name || "Sin descripción"
    specs_summary.present? ? "#{base} | #{specs_summary}" : base
  end

  private

  def must_have_variant_or_supplier_item
    if variant_id.blank? && supplier_item_id.blank?
      errors.add(:base, "Debe estar vinculado a una variante o a una pieza de proveedor")
    end
  end
end
