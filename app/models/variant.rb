class Variant < ApplicationRecord
  belongs_to :variant_type

  # EAV eliminado — properties ya no aplican a variantes
  has_many :compatibilities, dependent: :destroy
  has_many :reverse_compatibilities, as: :compatible, class_name: "Compatibility"

  has_many :supply_rules, dependent: :destroy
  has_many :supplier_items, through: :supply_rules

  validates :name, presence: true

  after_create :auto_link_to_rules, if: :active?
  after_commit :bust_decoder_cache

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

  # --------- Helpers proveeduría ----------

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

  def bust_decoder_cache
    ProductDecoder.bust_cache!
  end
end
