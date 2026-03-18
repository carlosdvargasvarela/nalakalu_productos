class FamilyVariantRule < ApplicationRecord
  belongs_to :family
  belongs_to :variant_type

  validates :position, presence: true

  after_create :propagate_to_family_products
  before_destroy :remove_from_family_products

  def display_name
    label.present? ? "#{variant_type.name} (#{label})" : variant_type.name
  end

  private

  def propagate_to_family_products
    family.products.each do |product|
      already_exists = product.product_variant_rules.exists?(
        variant_type_id: variant_type_id,
        label: label
      )
      next if already_exists

      product.product_variant_rules.create!(
        variant_type_id: variant_type_id,
        position: position,
        required: required,
        separator: separator,
        label: label
      )
    end
  end

  def remove_from_family_products
    family.products.each do |product|
      product.product_variant_rules
        .where(variant_type_id: variant_type_id, label: label)
        .destroy_all
    end
  end
end
