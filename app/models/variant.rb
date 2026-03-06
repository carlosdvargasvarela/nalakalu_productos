class Variant < ApplicationRecord
  belongs_to :variant_type
  belongs_to :provider, optional: true # Ahora es opcional

  validates :name, :code, presence: true
  validates :code, uniqueness: {scope: :variant_type_id, message: "ya existe para este tipo de variante"}

  # Relación de compatibilidad
  has_many :compatibilities, dependent: :destroy
  has_many :compatible_variants, through: :compatibilities, source: :compatible_variant

  # Lógica de respaldo (Fallback) antes de validar y guardar
  before_validation :ensure_technical_data

  # Lo que ve el vendedor en el generador (Ej: "Azul Petróleo")
  def seller_name
    display_name.presence || name
  end

  # Lo que se imprime en una Orden de Compra (Ej: "Lino Azul Petróleo - Ref: COL-742")
  def purchase_name
    parts = [name]
    parts << "Ref: #{provider_sku}" if provider_sku.present?
    parts.join(" - ")
  end

  def compatible_with?(other_variant)
    return true if compatible_variants.empty?
    compatible_variants.include?(other_variant)
  end

  private

  def ensure_technical_data
    # Si el nombre técnico está vacío, usamos el comercial
    self.name = display_name if name.blank?

    # Si el SKU del proveedor está vacío, usamos el código corto
    self.provider_sku = code if provider_sku.blank?
  end
end
