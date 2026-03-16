class Compatibility < ApplicationRecord
  belongs_to :variant
  # Ahora puede ser compatible con otra Variante o con un Producto
  belongs_to :compatible, polymorphic: true

  validate :not_self, if: -> { compatible_type == "Variant" }

  def not_self
    errors.add(:compatible_id, "no puede ser la misma variante") if variant_id == compatible_id
  end
end
