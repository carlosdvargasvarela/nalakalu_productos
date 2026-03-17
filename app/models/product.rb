class Product < ApplicationRecord
  belongs_to :family, optional: true

  has_many :product_variant_rules, -> { order(:position) }, dependent: :destroy
  has_many :variant_types, through: :product_variant_rules
  accepts_nested_attributes_for :product_variant_rules, allow_destroy: true

  # Compatibilidades: qué variantes son válidas para este producto
  has_many :reverse_compatibilities, as: :compatible, class_name: "Compatibility"
  has_many :allowed_variants, through: :reverse_compatibilities, source: :variant
  has_many :compatibilities, as: :compatible, class_name: "Compatibility"

  # Precios de variantes para este producto
  has_many :product_variant_prices, dependent: :destroy
  has_many :priced_variants, through: :product_variant_prices, source: :variant

  # Callbacks para heredar reglas de la familia
  before_save :flag_family_change, if: :will_save_change_to_family_id?
  after_save :sync_variant_rules_from_family, if: -> { @should_sync_rules }

  validates :name, presence: true, uniqueness: true
  validates :base_code, presence: true

  # --- MÉTODOS CLAVE PARA UI ---

  # Variantes de un tipo que son aptas para este producto (por compatibilidad)
  def compatible_variants_for(variant_type)
    allowed_variants.where(variant_type: variant_type)
  end

  # Reglas efectivas (por ahora: solo las propias del producto)
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

  # Tipo de proveedor según las variantes que requiere este producto
  def supplier_type
    type_ids = variant_types.pluck(:id)
    return "sin_definir" if type_ids.empty?

    provider_categories = Variant.where(variant_type_id: type_ids)
      .joins("LEFT JOIN providers ON providers.id = variants.provider_id")
      .pluck("providers.category")
      .compact
      .uniq

    if provider_categories.include?("interno") && provider_categories.include?("externo")
      "mixto"
    elsif provider_categories.include?("externo")
      "externo"
    elsif provider_categories.include?("interno") || provider_categories.empty?
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

  # Devuelve el precio configurado para una variante específica
  def price_for(variant)
    product_variant_prices.find_by(variant: variant)&.price || 0
  end

  # Crea o actualiza el precio para una variante
  def set_price_for!(variant, price)
    record = product_variant_prices.find_or_initialize_by(variant_id: variant.id)
    record.price = price
    record.save!
    record
  end

  private

  def flag_family_change
    @should_sync_rules = family_id_changed? && family.present?
  end

  def sync_variant_rules_from_family
    return unless @should_sync_rules

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

    @should_sync_rules = false
  end
end
