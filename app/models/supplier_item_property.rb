class SupplierItemProperty < ApplicationRecord
  belongs_to :supplier_item
  belongs_to :property_value

  delegate :value, to: :property_value
  delegate :property, to: :property_value

  validates :property_value_id, presence: true
  validates :property_value_id, uniqueness: {scope: :supplier_item_id,
                                             message: "ya está asignada a esta pieza"}

  default_scope { order(:position) }
end
