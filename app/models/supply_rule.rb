class SupplyRule < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :variant_type
  belongs_to :variant, optional: true
  belongs_to :supplier_item

  has_many :supply_rule_quantities, dependent: :destroy

  RULE_TYPES = %w[individual consolidated].freeze

  validates :rule_type, inclusion: {in: RULE_TYPES}
  validates :quantity_needed, numericality: {greater_than: 0}
  validates :variant_id, presence: true, if: -> { rule_type == "individual" && product_id.nil? }
  validates :variant_type_id, uniqueness: {
    scope: [:product_id, :rule_type],
    message: "ya existe una regla consolidada para este tipo de variante y producto"
  }, if: -> { rule_type == "consolidated" }

  scope :for_product, ->(product) { where(product_id: [product.id, nil]) }
  scope :consolidated, -> { where(rule_type: "consolidated") }
  scope :individual, -> { where(rule_type: "individual") }
  scope :global, -> { where(product_id: nil) }
  scope :ordered, -> {
    includes(:product, :variant)
      .references(:product, :variant)
      .order(Arel.sql("products.name ASC NULLS LAST, variants.name ASC NULLS LAST"))
  }

  def quantity_for(product)
    supply_rule_quantities.find_by(product: product)&.quantity_needed || quantity_needed
  end

  def display_name
    parts = []
    parts << (product&.name || "Todos los productos")
    parts << variant_type.name
    parts << (variant&.name || "Cualquier variante")
    parts.join(" → ")
  end
end
