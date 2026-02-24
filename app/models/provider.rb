class Provider < ApplicationRecord
  has_many :variants, dependent: :restrict_with_error

  accepts_nested_attributes_for :variants,
    allow_destroy: true,
    reject_if: :all_blank

  validates :name, presence: true, uniqueness: true
end
