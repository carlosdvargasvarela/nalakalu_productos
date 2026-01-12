class ProductVariantRule < ApplicationRecord
  belongs_to :product
  belongs_to :variant_type

  validates :position, presence: true
  # Un producto no debería tener el mismo tipo de variante dos veces
  validates :variant_type_id, uniqueness: { scope: :product_id }
end