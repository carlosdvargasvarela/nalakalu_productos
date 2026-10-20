module Reviewable
  extend ActiveSupport::Concern

  MODELS = %w[Family Product Variant VariantType Provider SupplierItem].freeze

  included do
    has_one :review, as: :reviewable, dependent: :destroy

    # nil = sin filtro
    scope :review_is, ->(status) do
      done = Review.where(reviewable_type: klass.name).where.not(status: "pending").select(:reviewable_id)
      case status
      when "pending" then where.not(id: done)
      when "approved", "needs_changes" then where(id: Review.where(reviewable_type: klass.name, status: status).select(:reviewable_id))
      end
    end
  end

  def review_status
    review&.status || "pending"
  end

  # Aprobado, pero el registro se editó después de la aprobación.
  def review_stale?
    review_status == "approved" && updated_at > review.updated_at
  end
end
