module Reviewable
  extend ActiveSupport::Concern

  MODELS = %w[Family Product Variant VariantType Provider SupplierItem].freeze

  included do
    has_one :review, as: :reviewable, dependent: :destroy
  end

  def review_status
    review&.status || "pending"
  end

  # Aprobado, pero el registro se editó después de la aprobación.
  def review_stale?
    review_status == "approved" && updated_at > review.updated_at
  end
end
