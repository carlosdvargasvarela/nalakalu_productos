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

  # ── Presentación básica ─────────────────────────────────────────
  def display_name
    sku.present? ? "#{name} (#{sku})" : name
  end

  def formatted_cost
    ActionController::Base.helpers.number_to_currency(default_cost || 0)
  end

  # ── Propiedades ─────────────────────────────────────────────────
  def has_properties?
    supplier_item_properties.any?
  end

  # Resumen legible para vistas (compatible con código existente)
  # Ej: "Ancho: 50mm | F1: MS-02 | F2: MS-03"
  def specs_summary
    supplier_item_properties
      .includes(property_value: :property)
      .map(&:label_display)
      .join(" | ")
  end

  # Descripción completa para mostrar en OC
  # Ej: "Base Fibra Mesa Cahuita (Ancho: 50mm, F1: MS-02, F2: MS-03)"
  def full_description(specifications = {})
    base = name

    spec_lines = supplier_item_properties.specs.map do |spec|
      value = specifications[spec.label]
      next unless value.present?

      "#{spec.label}: #{value}"
    end.compact

    return base if spec_lines.empty?

    "#{base}\n" + spec_lines.join("\n")
  end

  # Array de hashes para serializar en specifications JSON de la OC
  # Ej: [{label: "Ancho", value: "50mm"}, {label: "F1", value: "MS-02", variant_id: 3}]
  def default_specifications
    supplier_item_properties
      .properties
      .includes(property_value: :property)
      .map(&:to_spec)
      .compact
  end
end
