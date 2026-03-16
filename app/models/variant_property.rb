class VariantProperty < ApplicationRecord
  belongs_to :variant
  belongs_to :property_value
  has_one :property, through: :property_value
end
