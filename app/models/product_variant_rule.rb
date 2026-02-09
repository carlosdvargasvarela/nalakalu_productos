class ProductVariantRule < ApplicationRecord
  belongs_to :product
  belongs_to :variant_type

  validates :position, presence: true

  # NUEVA VALIDACIÓN: Ahora permitimos el mismo variant_type si tiene distinto label
  validates :variant_type_id, uniqueness: {
    scope: [:product_id, :label],
    message: "ya está asignado con esta etiqueta en este producto"
  }

  # Método para mostrar el nombre completo en la UI
  def display_name
    label.present? ? "#{variant_type.name} (#{label})" : variant_type.name
  end
end
