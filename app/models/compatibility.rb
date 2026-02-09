class Compatibility < ApplicationRecord
  belongs_to :variant
  belongs_to :compatible_variant, class_name: "Variant"

  validate :not_self

  def not_self
    errors.add(:compatible_variant_id, "no puede ser la misma variante") if variant_id == compatible_variant_id
  end
end