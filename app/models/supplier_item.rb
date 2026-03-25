class SupplierItem < ApplicationRecord
  belongs_to :provider

  has_many :supplier_item_properties, -> { order(:position) }, dependent: :destroy
  has_many :property_values, through: :supplier_item_properties
  has_many :properties, through: :property_values

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

  # Devuelve las specs formateadas para mostrar en OC o vistas
  # Ej: "N1: MS-01 | N2: MS-07 | N3: MS-03"
  def specs_summary
    supplier_item_properties
      .includes(property_value: :property)
      .map { |sip| "#{sip.property_value.property.name}: #{sip.property_value.value}" }
      .join(" | ")
  end

  def has_properties?
    supplier_item_properties.any?
  end
end
