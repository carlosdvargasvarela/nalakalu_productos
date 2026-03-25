# app/models/supplier_item_property.rb
class SupplierItemProperty < ApplicationRecord
  belongs_to :supplier_item

  validates :label, presence: true
  validates :value, presence: true
end