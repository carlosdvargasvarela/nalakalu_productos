class SupplierLink < ApplicationRecord
  include Tracked
  belongs_to :supplier_item
  belongs_to :product, optional: true
  belongs_to :variant, optional: true

  validates :supplier_item_id, uniqueness: {scope: [:product_id, :variant_id], message: "ya está vinculada así"}
  validate :product_or_variant

  def kind
    if product_id && variant_id then :product_variant
    elsif variant_id then :variant
    else :product
    end
  end

  def label
    [product&.name, variant && "#{variant.variant_type.name} → #{variant.seller_name}"].compact.join(" · ")
  end

  private

  def product_or_variant
    errors.add(:base, "Elige un producto, una variante o ambos") if product_id.blank? && variant_id.blank?
  end
end
