class Family < ApplicationRecord
  has_many :products, dependent: :nullify
  has_many :family_variant_rules, -> { order(:position) }, dependent: :destroy

  accepts_nested_attributes_for :family_variant_rules, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true, uniqueness: true
end
