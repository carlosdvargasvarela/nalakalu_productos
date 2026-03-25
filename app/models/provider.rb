class Provider < ApplicationRecord
  has_many :supplier_items, dependent: :destroy
  has_many :purchase_orders, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  CATEGORIES = %w[interno externo].freeze
  validates :category, inclusion: {in: CATEGORIES}

  scope :active, -> { where(active: true) }
  scope :internos, -> { where(category: "interno") }
  scope :externos, -> { where(category: "externo") }
end
