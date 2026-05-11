class Recommendation < ApplicationRecord
  belongs_to :variant_type
  belongs_to :product, optional: true

  TYPES = %w[new_variant new_product_variant_rule].freeze
  STATUSES = %w[pending approved rejected].freeze

  validates :recommendation_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :suggested_variant_name, presence: true, if: -> { recommendation_type == "new_variant" }
  validates :product_id, presence: true, if: -> { recommendation_type == "new_product_variant_rule" }

  scope :pending, -> { where(status: "pending") }
  scope :resolved, -> { where.not(status: "pending") }
  scope :ordered, -> { order(created_at: :desc) }

  def approve!
    ActiveRecord::Base.transaction do
      case recommendation_type
      when "new_variant"
        Variant.create!(
          variant_type: variant_type,
          name: suggested_variant_name,
          code: suggested_variant_code.presence,
          active: true
        )
      when "new_product_variant_rule"
        next_position = product.product_variant_rules.maximum(:position).to_i + 1
        ProductVariantRule.create!(
          product: product,
          variant_type: variant_type,
          position: next_position,
          required: true,
          separator: "-"
        )
      end
      update!(status: "approved")
    end
  end

  def type_label
    case recommendation_type
    when "new_variant" then "Nueva variante"
    when "new_product_variant_rule" then "Asociar tipo al producto"
    end
  end
end
