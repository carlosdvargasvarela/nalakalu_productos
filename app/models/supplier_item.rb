class SupplierItem < ApplicationRecord
  belongs_to :provider

  has_many :supply_rules, dependent: :destroy
  has_many :procurement_requirements, dependent: :destroy
  has_many :purchase_order_items, dependent: :nullify

  validates :name, presence: true
  validates :unit, presence: true
  validates :default_cost, numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  UNITS = %w[unidad metro rollo par juego kg litro].freeze

  scope :active, -> { where(active: true) }

  def display_name
    sku.present? ? "#{name} (#{sku})" : name
  end

  def formatted_cost
    ActionController::Base.helpers.number_to_currency(default_cost || 0)
  end
end
