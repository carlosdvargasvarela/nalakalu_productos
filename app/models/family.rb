class Family < ApplicationRecord
  has_many :products, dependent: :nullify
  has_many :family_variant_rules, -> { order(:position) }, dependent: :destroy

  accepts_nested_attributes_for :family_variant_rules,
    allow_destroy: true,
    reject_if: :all_blank

  validates :name, presence: true, uniqueness: true

  # Propaga la eliminación de una regla a los productos de la familia
  def remove_rule_from_products(family_rule)
    products.each do |product|
      product.product_variant_rules
        .where(variant_type_id: family_rule.variant_type_id, label: family_rule.label)
        .destroy_all
    end
  end
end
