class SupplyRule < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :variant_type
  belongs_to :variant, optional: true
  belongs_to :supplier_item

  RULE_TYPES = %w[individual consolidated].freeze

  validates :rule_type, inclusion: {in: RULE_TYPES}
  validates :quantity_needed, numericality: {greater_than: 0}

  # Una regla individual necesita una variante específica
  validates :variant_id, presence: true, if: -> { rule_type == "individual" }

  scope :for_product, ->(product) {
    where(product_id: [product.id, nil])
  }

  scope :consolidated, -> { where(rule_type: "consolidated") }
  scope :individual, -> { where(rule_type: "individual") }

  def applies_globally?
    product_id.nil? && variant_id.nil?
  end

  def display_name
    parts = []
    parts << (product&.name || "Todos los productos")
    parts << variant_type.name
    parts << (variant&.name || "Cualquier variante")
    parts.join(" → ")
  end
end
