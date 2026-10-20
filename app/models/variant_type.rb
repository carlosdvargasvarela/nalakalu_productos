class VariantType < ApplicationRecord
  include Tracked
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
      scope.each { ChangeLog.log(_1, "destroy", _1.attributes, nil) }
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
          ChangeLog.log(ProductVariantRule.find(rid), "create", nil, ProductVariantRule.find(rid).attributes) # sus compatibilidades se eliminan en cascada al deshacer
        end
      else
        ProductVariantRule.where(variant_type_id: target.id).pluck(:id).each do |rid|
          moved_ids.each { |vid| Compatibility.find_or_create_by!(variant_id: vid, compatible_type: "ProductVariantRule", compatible_id: rid) }
        end
      end
      moved.size
    end
  end

  # Une este tipo con otro (target): las variantes pasan a target y todo lo que usaba este tipo pasa a usar target
  # sin perder las variantes que ya tenían permitidas. Este tipo queda oculto (inactivo), no se borra.
  def merge_into!(target)
    raise ArgumentError, "no se puede unir un tipo consigo mismo" if target.id == id

    transaction do
      # 1) reglas de producto: si el producto ya usa el tipo destino (misma etiqueta) se funden; si no, se re-apuntan
      ProductVariantRule.where(variant_type_id: id).find_each do |rule|
        keep = ProductVariantRule.find_by(product_id: rule.product_id, variant_type_id: target.id, label: rule.label)
        if keep
          have = Compatibility.where(compatible_type: "ProductVariantRule", compatible_id: keep.id).pluck(:variant_id).to_set
          Compatibility.where(compatible_type: "ProductVariantRule", compatible_id: rule.id).each { |c| c.update!(compatible_id: keep.id) unless have.include?(c.variant_id) }
          rule.reload.destroy
        else
          rule.update!(variant_type_id: target.id) # sus variantes permitidas quedan atadas a la misma regla
        end
      end
      # 2) reglas de familia (el orden importa: las de producto ya apuntan al destino, así borrar una de familia no toca productos)
      FamilyVariantRule.where(variant_type_id: id).find_each do |fr|
        if FamilyVariantRule.exists?(family_id: fr.family_id, variant_type_id: target.id, label: fr.label)
          fr.destroy
        else
          fr.update!(variant_type_id: target.id)
        end
      end
      # 3) variantes
      variants.reload.each { _1.update!(variant_type_id: target.id) }
      update!(active: false)
    end
  end

  private

  def assign_position
    self.position = (VariantType.maximum(:position) || 0) + 1
  end
end
