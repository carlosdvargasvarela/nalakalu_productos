class VariantPricing < ApplicationRecord
  belongs_to :variant
  validates :unit, :cost, presence: true

  def display_label
    "#{unit.upcase} - $#{cost}"
  end
end
