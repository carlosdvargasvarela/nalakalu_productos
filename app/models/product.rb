class Product < ApplicationRecord
  belongs_to :family, optional: true

  has_many :product_variant_rules, -> { order(:position) }, dependent: :destroy
  has_many :variant_types, through: :product_variant_rules

  accepts_nested_attributes_for :product_variant_rules, allow_destroy: true, reject_if: :all_blank

  validates :name, :base_code, presence: true
  validates :base_code, uniqueness: true

  # Decide qué reglas usar: las propias del producto, las de su familia, o ninguna
  def effective_rules
    if product_variant_rules.any?
      product_variant_rules
    elsif family.present?
      family.family_variant_rules
    else
      []
    end
  end

  # Actualizado para usar effective_rules
  def code_structure_preview
    rules = effective_rules
    return base_code if rules.empty?

    parts = [base_code]
    rules.each do |rule|
      parts << "#{rule.separator}[#{rule.variant_type.name}]"
    end
    parts.join("")
  end
end
