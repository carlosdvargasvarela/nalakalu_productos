class Property < ApplicationRecord
  has_many :property_values, dependent: :destroy
  validates :name, presence: true, uniqueness: true
end
