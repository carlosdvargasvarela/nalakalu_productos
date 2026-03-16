class PropertyValue < ApplicationRecord
  belongs_to :property
  has_many :variant_properties, dependent: :destroy
  has_many :variants, through: :variant_properties

  validates :value, presence: true, uniqueness: { scope: :property_id }
end