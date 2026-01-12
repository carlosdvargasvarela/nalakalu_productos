class Provider < ApplicationRecord
  has_many :variants, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: true
end