class SupplierItemProperty < ApplicationRecord
  belongs_to :supplier_item
  belongs_to :property_value, optional: true

  SPEC_TYPES = %w[property spec].freeze

  default_scope { order(:position) }

  # ── Validaciones ────────────────────────────────────────────────
  validates :spec_type, inclusion: {in: SPEC_TYPES}

  with_options if: :property? do
    validates :property_value, presence: true
    validates :property_value_id,
      uniqueness: {
        scope: :supplier_item_id,
        message: "ya está asignada a esta pieza"
      }
  end

  with_options if: :spec? do
    validates :label, presence: true
  end

  # ── Scopes ──────────────────────────────────────────────────────
  scope :properties, -> { where(spec_type: "property") }
  scope :specs, -> { where(spec_type: "spec") }

  # ── Helpers ─────────────────────────────────────────────────────
  def property?
    spec_type == "property"
  end

  def spec?
    spec_type == "spec"
  end

  # ── Presentación ────────────────────────────────────────────────
  def label_display
    if property?
      "#{property_value.property.name}: #{property_value.value}"
    else
      label
    end
  end

  # importante: ahora specs no llevan valor aquí
  def to_spec
    return unless property?

    {
      label: property_value.property.name,
      value: property_value.value
    }
  end

  def label
    if spec_type == "property"
      property_value&.property&.name
    else
      read_attribute(:label) # El campo label de la DB
    end
  end

  def value
    if spec_type == "property"
      property_value&.value
    else
      "___" # O lo que quieras mostrar para los labels dinámicos (F1, F2)
    end
  end
end
