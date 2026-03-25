class Variant < ApplicationRecord
  belongs_to :variant_type

  has_many :variant_properties, dependent: :destroy
  has_many :property_values, through: :variant_properties
  has_many :properties, through: :property_values

  has_many :compatibilities, dependent: :destroy
  has_many :reverse_compatibilities, as: :compatible, class_name: "Compatibility"

  has_many :supply_rules, dependent: :destroy
  has_many :supplier_items, through: :supply_rules

  accepts_nested_attributes_for :variant_properties,
    allow_destroy: true,
    reject_if: ->(attrs) { attrs["property_value_id"].blank? }

  validates :name, presence: true

  after_create :auto_link_to_rules, if: :active?

  # --------- Helpers EAV ----------

  def get_prop(prop_name)
    property_values.joins(:property).find_by(properties: {name: prop_name})&.value
  end

  # --------- Helpers compatibilidad ----------

  def compatible_product_ids
    rule_ids = compatibilities.where(compatible_type: "ProductVariantRule").pluck(:compatible_id)
    ProductVariantRule.where(id: rule_ids).pluck(:product_id).uniq
  end

  def compatible_variant_ids
    compatibilities.where(compatible_type: "Variant").pluck(:compatible_id)
  end

  def compatible_variant_ids=(ids)
    ids = Array(ids).reject(&:blank?).map(&:to_i).uniq
    compatibilities.where(compatible_type: "Variant").where.not(compatible_id: ids).destroy_all
    existing_ids = compatibilities.where(compatible_type: "Variant").pluck(:compatible_id)
    (ids - existing_ids).each do |vid|
      compatibilities.build(compatible_type: "Variant", compatible_id: vid)
    end
  end

  def compatible_variants
    Variant.where(id: compatibilities.where(compatible_type: "Variant").pluck(:compatible_id))
  end

  # Nombre para mostrar al vendedor/usuario
  def seller_name
    display_name.presence || name
  end

  # Descripción técnica completa con propiedades EAV
  def technical_specs_string
    property_values.includes(:property)
      .order("properties.name")
      .map { |pv| "#{pv.property.name}: #{pv.value}" }
      .join(", ")
  end

  def full_description
    [name, technical_specs_string].reject(&:blank?).join(" | ")
  end

  # --------- Helpers proveeduría ----------

  # Devuelve el supplier_item que aplica para un producto específico.
  # Primero busca una regla específica para ese producto,
  # luego una regla genérica (product_id nil).
  def supplier_item_for(product)
    rule = supply_rules.find_by(product: product) || supply_rules.find_by(product: nil)
    rule&.supplier_item
  end

  def has_supply_rules?
    supply_rules.exists?
  end

  def consolidated_procurement?
    variant_type.consolidated?
  end

  private

  def auto_link_to_rules
    ProductVariantRule.where(variant_type_id: variant_type_id).each do |rule|
      Compatibility.find_or_create_by!(
        variant_id: id,
        compatible_type: "ProductVariantRule",
        compatible_id: rule.id
      )
    end
  end
end
