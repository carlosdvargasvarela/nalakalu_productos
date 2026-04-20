class ProductVariantRule < ApplicationRecord
  belongs_to :product
  belongs_to :variant_type

  has_many :compatibilities, as: :compatible, class_name: "Compatibility", dependent: :destroy
  has_many :allowed_variants, through: :compatibilities, source: :variant

  validates :position, presence: true
  validates :variant_type_id, uniqueness: {
    scope: [:product_id, :label],
    message: "ya está asignado con esta etiqueta en este producto"
  }

  after_create_commit :auto_link_variants_to_rule

  def display_name
    label.present? ? "#{variant_type.name} (#{label})" : variant_type.name
  end

  private

  def auto_link_variants_to_rule
    return if variant_type_id.blank?

    v_ids = Variant.where(variant_type_id: variant_type_id, active: true).pluck(:id)
    return if v_ids.empty?

    now = Time.current
    rows = v_ids.map do |v_id|
      {
        variant_id: v_id,
        compatible_type: "ProductVariantRule",
        compatible_id: id,
        created_at: now,
        updated_at: now
      }
    end

    Compatibility.insert_all(rows)
  end
end
