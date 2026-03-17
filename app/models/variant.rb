# app/models/variant.rb
class Variant < ApplicationRecord
  belongs_to :variant_type
  belongs_to :provider, optional: true

  has_many :variant_properties, dependent: :destroy
  has_many :property_values, through: :variant_properties
  has_many :properties, through: :property_values

  has_many :compatibilities, dependent: :destroy      # variant -> compatible (Variant/Product)
  has_many :reverse_compatibilities,                  # compatible(Product/Variant) -> this variant
    as: :compatible,
    class_name: "Compatibility"

  has_many :product_variant_prices, dependent: :destroy

  accepts_nested_attributes_for :variant_properties, allow_destroy: true

  validates :name, presence: true

  # --------- Helpers EAV ----------
  def get_prop(prop_name)
    property_values.joins(:property).find_by(properties: {name: prop_name})&.value
  end

  # --------- Helpers compatibilidad para formularios ----------
  def compatible_product_ids
    compatibilities.where(compatible_type: "Product").pluck(:compatible_id)
  end

  def compatible_product_ids=(ids)
    ids = Array(ids).reject(&:blank?).map(&:to_i).uniq

    compatibilities.where(compatible_type: "Product")
      .where.not(compatible_id: ids)
      .destroy_all

    existing_ids = compatibilities.where(compatible_type: "Product").pluck(:compatible_id)
    (ids - existing_ids).each do |pid|
      compatibilities.build(compatible_type: "Product", compatible_id: pid)
    end
  end

  def compatible_variant_ids
    compatibilities.where(compatible_type: "Variant").pluck(:compatible_id)
  end

  def compatible_variant_ids=(ids)
    ids = Array(ids).reject(&:blank?).map(&:to_i).uniq

    compatibilities.where(compatible_type: "Variant")
      .where.not(compatible_id: ids)
      .destroy_all

    existing_ids = compatibilities.where(compatible_type: "Variant").pluck(:compatible_id)
    (ids - existing_ids).each do |vid|
      compatibilities.build(compatible_type: "Variant", compatible_id: vid)
    end
  end

  def seller_name
    display_name.presence || name
  end

  def purchase_name
    parts = [name]
    parts << "Ref: #{provider_sku}" if provider_sku.present?
    parts.join(" - ")
  end

  def compatible_variants
    Variant.where(id: compatibilities.where(compatible_type: "Variant").pluck(:compatible_id))
  end

  def compatible_products
    Product.where(id: compatibilities.where(compatible_type: "Product").pluck(:compatible_id))
  end
end
