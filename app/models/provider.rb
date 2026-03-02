class Provider < ApplicationRecord
  has_many :variants, dependent: :restrict_with_error

  accepts_nested_attributes_for :variants,
    allow_destroy: true,
    reject_if: :all_blank

  validates :name, presence: true, uniqueness: true

  # Definimos las categorías
  CATEGORIES = %w[interno externo].freeze

  validates :category, inclusion: {in: CATEGORIES}

  # Scopes para facilitar consultas
  scope :internos, -> { where(category: "interno") }
  scope :externos, -> { where(category: "externo") }
end
