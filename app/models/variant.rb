class Variant < ApplicationRecord
  belongs_to :variant_type
  belongs_to :provider, optional: true

  has_many :variant_properties, dependent: :destroy
  has_many :property_values, through: :variant_properties
  has_many :properties, through: :property_values

  has_many :compatibilities, dependent: :destroy

  # Precios específicos cuando se usa en un producto determinado
  has_many :product_variant_prices, dependent: :destroy

  validates :name, presence: true

  before_validation :ensure_technical_data

  # Helper para obtener el valor de una propiedad (ej: variant.get_prop("Acabado"))
  def get_prop(prop_name)
    property_values.joins(:property).find_by(properties: {name: prop_name})&.value
  end

  def seller_name
    display_name.presence || name
  end

  # Lo que se imprime en una Orden de Compra (Ej: "Lino Azul Petróleo - Ref: COL-742")
  def purchase_name
    parts = [name]
    parts << "Ref: #{provider_sku}" if provider_sku.present?
    parts.join(" - ")
  end

  private

  def ensure_technical_data
    # Si el nombre técnico está vacío, usamos el comercial
    self.name = display_name if name.blank?

    # Si el SKU del proveedor está vacío, usamos el código corto
    self.provider_sku = code if provider_sku.blank?
  end
end
