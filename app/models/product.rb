class Product < ApplicationRecord
  has_many :product_variant_rules, -> { order(:position) }, dependent: :destroy
  has_many :variant_types, through: :product_variant_rules

  # Esto permite guardar las reglas junto con el producto en el mismo formulario
  accepts_nested_attributes_for :product_variant_rules, allow_destroy: true, reject_if: :all_blank

  validates :name, :base_code, presence: true
  validates :base_code, uniqueness: true

  # Método de conveniencia para ver cómo quedará el código
  def code_structure_preview
    parts = [base_code]
    product_variant_rules.each do |rule|
      parts << "#{rule.separator}[#{rule.variant_type.name}]"
    end
    parts.join("")
  end
end