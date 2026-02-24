class FamilyVariantRule < ApplicationRecord
  belongs_to :family
  belongs_to :variant_type

  validates :position, presence: true

  def display_name
    label.present? ? "#{variant_type.name} (#{label})" : variant_type.name
  end
end
