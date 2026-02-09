class Variant < ApplicationRecord
  belongs_to :variant_type
  belongs_to :provider
  
  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :variant_type_id, message: "ya existe para este tipo de variante" }

  # Relación de compatibilidad
  has_many :compatibilities, dependent: :destroy
  has_many :compatible_variants, through: :compatibilities, source: :compatible_variant

  # Método para verificar si es compatible con otra
  def compatible_with?(other_variant)
    return true if compatible_variants.empty? # Si no hay reglas, asumimos que es libre
    compatible_variants.include?(other_variant)
  end
end