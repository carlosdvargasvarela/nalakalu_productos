class Product < ApplicationRecord
  belongs_to :family, optional: true

  has_many :product_variant_rules, -> { order(:position) }, dependent: :destroy
  has_many :variant_types, through: :product_variant_rules
  accepts_nested_attributes_for :product_variant_rules, allow_destroy: true

  # Relaciones de proveeduría
  has_many :supply_rules, dependent: :destroy
  has_many :supplier_items, through: :supply_rules

  before_save :flag_family_change, if: :will_save_change_to_family_id?
  after_save :sync_variant_rules_from_family, if: -> { @should_sync_rules }

  validates :name, presence: true, uniqueness: true
  validates :base_code, presence: true

  # --------- Helpers de variantes ----------

  def compatible_variants_for_rule(rule)
    rule.allowed_variants
  end

  def compatible_variants_for(variant_type)
    rule_ids = product_variant_rules.where(variant_type: variant_type).pluck(:id)
    Variant.joins(:compatibilities)
      .where(compatibilities: {compatible_type: "ProductVariantRule", compatible_id: rule_ids})
      .distinct
  end

  def effective_rules
    product_variant_rules.any? ? product_variant_rules : []
  end

  def code_structure_preview
    rules = effective_rules
    return base_code if rules.empty?

    parts = [base_code]
    rules.each do |rule|
      parts << "#{rule.separator}[#{rule.variant_type.name}]"
    end
    parts.join("")
  end

  # --------- Helpers de proveedor ----------

  # Determina el tipo de proveedor del producto según sus SupplierItems configurados.
  def supplier_type
    categories = supplier_items
      .joins(:provider)
      .pluck("providers.category")
      .compact.uniq

    if categories.include?("interno") && categories.include?("externo")
      "mixto"
    elsif categories.include?("externo")
      "externo"
    elsif categories.include?("interno")
      "interno"
    else
      "sin_definir"
    end
  end

  def supplier_type_color
    case supplier_type
    when "interno" then "success"
    when "externo" then "warning"
    when "mixto" then "info"
    else "secondary"
    end
  end

  # --------- Helpers de proveeduría ----------

  # Resuelve todos los supplier_items necesarios para una combinación de variantes.
  # Recibe un array de Variant y devuelve un hash { supplier_item => specs }
  def resolve_supplier_items(variants)
    result = {}

    individual_variants = variants.select { |v| v.variant_type.individual? }
    consolidated_variants = variants.select { |v| v.variant_type.consolidated? }

    # Individuales: cada variante resuelve su propia pieza
    individual_variants.each do |variant|
      rule = supply_rules.find_by(variant: variant) ||
        SupplyRule.find_by(product: nil, variant: variant)
      next unless rule
      result[rule.supplier_item] = {}
    end

    # Consolidados: agrupar por tipo y resolver una sola pieza con specs
    consolidated_variants.group_by(&:variant_type).each do |variant_type, type_variants|
      rule = supply_rules.find_by(variant_type: variant_type, rule_type: "consolidated") ||
        SupplyRule.find_by(product: nil, variant_type: variant_type, rule_type: "consolidated")
      next unless rule

      specs = {}
      type_variants.each do |v|
        label = product_variant_rules.find_by(variant_type: variant_type)&.label
        key = label.presence || variant_type.name
        specs[key] = v.name
      end

      result[rule.supplier_item] = specs
    end

    result
  end

  # Indica si el producto tiene todas sus reglas de abastecimiento configuradas
  def procurement_ready?
    variant_types.all? do |vt|
      supply_rules.exists?(variant_type: vt)
    end
  end

  private

  def flag_family_change
    @should_sync_rules = will_save_change_to_family_id? && family_id.present?
  end

  def sync_variant_rules_from_family
    return unless @should_sync_rules
    ActiveRecord::Base.transaction do
      product_variant_rules.destroy_all

      family.family_variant_rules.each do |fr|
        product_variant_rules.create!(
          variant_type_id: fr.variant_type_id,
          position: fr.position,
          required: fr.required,
          separator: fr.separator,
          label: fr.label
        )
      end
    end
    @should_sync_rules = false
  end
end
