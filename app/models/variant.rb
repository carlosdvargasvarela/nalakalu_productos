class Variant < ApplicationRecord
  belongs_to :variant_type
  belongs_to :provider, optional: true

  has_many :variant_properties, dependent: :destroy
  has_many :property_values, through: :variant_properties
  has_many :properties, through: :property_values

  has_many :compatibilities, dependent: :destroy
  has_many :reverse_compatibilities, as: :compatible, class_name: "Compatibility"

  has_many :product_variant_prices, dependent: :destroy
  has_many :priced_products, through: :product_variant_prices, source: :product

  # Relaciones de proveeduría
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

  def seller_name
    display_name.presence || name
  end

  def purchase_name
    parts = [name]
    parts << "Ref: #{provider_sku}" if provider_sku.present?
    parts.join(" - ")
  end

  def prices_by_product
    product_variant_prices.includes(:product)
  end

  def price_for_product(product)
    product_variant_prices.find_by(product_id: product.id)&.price
  end

  def technical_specs_string
    property_values.includes(:property)
      .order("properties.name")
      .map { |pv| "#{pv.property.name}: #{pv.value}" }
      .join(", ")
  end

  def full_purchase_description
    [name, technical_specs_string].reject(&:blank?).join(" | ")
  end

  # --------- Helpers proveeduría ----------

  # Devuelve el supplier_item que aplica para un producto específico
  def supplier_item_for(product)
    rule = supply_rules.find_by(product: product) || supply_rules.find_by(product: nil)
    rule&.supplier_item
  end

  # Indica si esta variante tiene reglas de compra configuradas
  def has_supply_rules?
    supply_rules.exists?
  end

  # Indica si el tipo de variante es consolidado (ej: Fibras N1, N2, N3)
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
