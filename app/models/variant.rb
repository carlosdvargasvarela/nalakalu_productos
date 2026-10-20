class Variant < ApplicationRecord
  include Tracked
  include Reviewable
  belongs_to :variant_type

  # EAV eliminado — properties ya no aplican a variantes
  has_many :compatibilities, dependent: :destroy
  has_many :reverse_compatibilities, as: :compatible, class_name: "Compatibility"

  has_many :supply_rules, dependent: :destroy
  has_many :supplier_links, dependent: :destroy
  has_many :supplier_items, -> { distinct }, through: :supplier_links

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

  # Copia con las mismas compatibilidades (con reglas de producto y con otras variantes). El código queda vacío.
  def duplicate!
    transaction do
      n = 1
      n += 1 while Variant.exists?(variant_type_id: variant_type_id, name: (candidate = "#{name} (copia#{" #{n}" if n > 1})"))
      copy = Variant.create!(variant_type_id: variant_type_id, name: candidate, display_name: display_name.presence && "#{display_name} (copia)",
        technical_description: technical_description, active: active)
      Compatibility.where(variant_id: copy.id).delete_all # las que creó el callback automático
      now = Time.current
      rows = compatibilities.map { {variant_id: copy.id, compatible_type: _1.compatible_type, compatible_id: _1.compatible_id, created_at: now, updated_at: now} }
      Compatibility.insert_all(rows) if rows.any?
      copy
    end
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
    ProductDecoder.clear_cache!
  end
end
