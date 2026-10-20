class VariantType < ApplicationRecord
  include Reviewable
  has_many :variants, dependent: :destroy
  has_many :supply_rules, dependent: :destroy
  has_many :product_variant_rules, dependent: :destroy
  has_many :family_variant_rules, dependent: :destroy
  has_many :recommendations, dependent: :destroy

  PROCUREMENT_STRATEGIES = %w[individual consolidated].freeze

  validates :name, presence: true, uniqueness: true
  validates :procurement_strategy, inclusion: {in: PROCUREMENT_STRATEGIES}

  before_create :assign_position

  scope :active, -> { where(active: true) }
  scope :consolidated, -> { where(procurement_strategy: "consolidated") }
  scope :individual, -> { where(procurement_strategy: "individual") }

  def consolidated?
    procurement_strategy == "consolidated"
  end

  def individual?
    procurement_strategy == "individual"
  end

  # Mueve variantes a otro tipo.
  # carry_to_products (solo si el destino es un tipo nuevo, sin reglas): a cada producto que usaba este tipo
  # y tenía alguna de las variantes movidas, se le agrega una regla del tipo nuevo (al final del código, opcional)
  # con esas mismas variantes permitidas. Si no, las variantes movidas pasan a las reglas que ya use el destino.
  def move_variants_to!(target, variant_ids, carry_to_products: false)
    transaction do
      moved = variants.where(id: variant_ids).to_a
      return 0 if moved.empty?

      moved_ids = moved.map(&:id)
      old_rule_ids = ProductVariantRule.where(variant_type_id: id).select(:id)
      scope = Compatibility.where(compatible_type: "ProductVariantRule", compatible_id: old_rule_ids, variant_id: moved_ids)
      allowed = scope.pluck(:compatible_id, :variant_id).group_by(&:first).transform_values { |a| a.map(&:last) }
      scope.delete_all
      moved.each { _1.update!(variant_type: target) }

      now = Time.current
      if carry_to_products
        allowed.each do |rule_id, vids|
          r = ProductVariantRule.find(rule_id)
          pos = ProductVariantRule.where(product_id: r.product_id).maximum(:position).to_i + 1
          rid = ProductVariantRule.insert_all(
            [{product_id: r.product_id, variant_type_id: target.id, position: pos, required: false, separator: r.separator, label: r.label, created_at: now, updated_at: now}],
            returning: %w[id]
          ).rows.first.first
          Compatibility.insert_all(vids.map { {variant_id: _1, compatible_type: "ProductVariantRule", compatible_id: rid, created_at: now, updated_at: now} })
        end
      else
        ProductVariantRule.where(variant_type_id: target.id).pluck(:id).each do |rid|
          moved_ids.each { |vid| Compatibility.find_or_create_by!(variant_id: vid, compatible_type: "ProductVariantRule", compatible_id: rid) }
        end
      end
      moved.size
    end
  end

  private

  def assign_position
    self.position = (VariantType.maximum(:position) || 0) + 1
  end
end
