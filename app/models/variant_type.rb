class VariantType < ApplicationRecord
  has_many :variants, dependent: :destroy
  validates :name, presence: true, uniqueness: true
  before_create :assign_position

  private

  def assign_position
    self.position = (VariantType.maximum(:position) || 0) + 1
  end
end
