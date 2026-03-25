class VariantType < ApplicationRecord
  has_many :variants, dependent: :destroy
  has_many :supply_rules, dependent: :destroy

  PROCUREMENT_STRATEGIES = %w[individual consolidated].freeze

  validates :name, presence: true, uniqueness: true
  validates :procurement_strategy, inclusion: {in: PROCUREMENT_STRATEGIES}

  before_create :assign_position

  scope :active, -> { where(active: true) }
  scope :consolidated, -> { where(procurement_strategy: "consolidated") }
  scope :individual, -> { where(procurement_strategy: "individual") }

  def consolidated?
    procurement_strategy == "consolidated"
  end

  def individual?
    procurement_strategy == "individual"
  end

  private

  def assign_position
    self.position = (VariantType.maximum(:position) || 0) + 1
  end
end
