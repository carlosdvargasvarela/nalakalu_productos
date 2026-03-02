class Product < ApplicationRecord
  belongs_to :family, optional: true

  has_many :product_variant_rules, -> { order(:position) }, dependent: :destroy
  has_many :variant_types, through: :product_variant_rules

  accepts_nested_attributes_for :product_variant_rules, allow_destroy: true, reject_if: :all_blank

  validates :name, :base_code, presence: true
  validates :base_code, uniqueness: true

  before_save :flag_family_change
  after_save :sync_variant_rules_from_family

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

  def supplier_type
    # Obtenemos los tipos de proveedores de todas las variantes posibles
    # que este producto puede tener según sus reglas (variant_types)
    provider_categories = Variant.where(variant_type_id: variant_types.pluck(:id))
      .joins(:provider)
      .pluck("providers.category")
      .uniq

    if provider_categories.include?("interno") && provider_categories.include?("externo")
      "mixto"
    elsif provider_categories.include?("externo")
      "externo"
    elsif provider_categories.include?("interno")
      "interno"
    else
      "sin_definir"
    end
  end

  # Helper para badges de UI
  def supplier_type_color
    case supplier_type
    when "interno" then "success"
    when "externo" then "warning"
    when "mixto" then "info"
    else "secondary"
    end
  end

  private

  def flag_family_change
    @should_sync_rules = family_id_changed? && family.present?
  end

  def sync_variant_rules_from_family
    return unless @should_sync_rules

    # Limpiar reglas anteriores y clonar las de la nueva familia
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
