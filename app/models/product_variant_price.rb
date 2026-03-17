# app/models/product_variant_price.rb
class ProductVariantPrice < ApplicationRecord
  belongs_to :product
  belongs_to :variant

  validates :price, presence: true, numericality: {greater_than_or_equal_to: 0}
  # Evitamos duplicados: un producto solo puede tener un precio para una variante específica
  validates :variant_id, uniqueness: {scope: :product_id, message: "ya tiene un precio asignado para este producto"}

  # Helper para mostrar el precio formateado
  def formatted_price
    ActionController::Base.helpers.number_to_currency(price)
  end
end
