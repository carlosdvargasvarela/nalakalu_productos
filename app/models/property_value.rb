class PropertyValue < ApplicationRecord
  belongs_to :property

  has_many :supplier_item_properties, dependent: :destroy
  has_many :supplier_items, through: :supplier_item_properties

  validates :value, presence: true, uniqueness: {scope: :property_id}

  def full_label
    "#{property.name}: #{value}"
  end
end
