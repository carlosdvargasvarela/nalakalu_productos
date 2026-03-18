class ProductVariantRule < ApplicationRecord
  belongs_to :product
  belongs_to :variant_type

  # La regla es dueña de sus variantes permitidas
  has_many :compatibilities, as: :compatible, class_name: "Compatibility", dependent: :destroy
  has_many :allowed_variants, through: :compatibilities, source: :variant

  validates :position, presence: true
  validates :variant_type_id, uniqueness: {
    scope: [:product_id, :label],
    message: "ya está asignado con esta etiqueta en este producto"
  }

  after_create :auto_link_variants_to_rule

  def display_name
    label.present? ? "#{variant_type.name} (#{label})" : variant_type.name
  end

  private

  def auto_link_variants_to_rule
    variant_type.variants.where(active: true).each do |variant|
      Compatibility.find_or_create_by!(
        variant_id: variant.id,
        compatible_type: "ProductVariantRule",
        compatible_id: id
      )
    end
  end
end
