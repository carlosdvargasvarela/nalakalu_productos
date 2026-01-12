class VariantType < ApplicationRecord
  has_many :variants, dependent: :destroy
  validates :name, presence: true, uniqueness: true
end