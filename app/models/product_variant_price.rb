# app/models/product_variant_price.rb
class ProductVariantPrice < ApplicationRecord
  belongs_to :product
  belongs_to :variant

  validates :product_id, :variant_id, presence: true
  validates :price, numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  validates :variant_id, uniqueness: {
    scope: :product_id,
    message: "ya tiene un precio definido para este producto"
  }

  # Para la UI
  def display_label
    "#{product.name} - #{variant.seller_name} (#{variant.code})"
  end
end
