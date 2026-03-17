class ProductVariantRule < ApplicationRecord
  belongs_to :product
  belongs_to :variant_type

  validates :position, presence: true
  validates :variant_type_id, uniqueness: {
    scope: [:product_id, :label],
    message: "ya está asignado con esta etiqueta en este producto"
  }

  # MAGIA: Al crear la regla, vinculamos las variantes al producto
  after_create :auto_link_variants_to_product

  def display_name
    label.present? ? "#{variant_type.name} (#{label})" : variant_type.name
  end

  private

  def auto_link_variants_to_product
    # Buscamos todas las variantes activas de este tipo
    variants_to_link = variant_type.variants.where(active: true)

    variants_to_link.each do |variant|
      # Creamos la compatibilidad polimórfica: Variante -> Producto
      # Usamos find_or_create_by para evitar errores si ya existía
      Compatibility.find_or_create_by!(
        variant_id: variant.id,
        compatible_type: "Product",
        compatible_id: product_id
      )
    end
  end
end
