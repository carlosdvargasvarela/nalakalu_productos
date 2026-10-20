class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  def create
    type = params.require(:reviewable_type)
    return head :bad_request unless Reviewable::MODELS.include?(type)

    record = type.constantize.find(params.require(:reviewable_id))
    review = record.review || record.build_review
    review.assign_attributes(params.permit(:status, :note).merge(user: current_user))

    if review.save
      redirect_back_or_to polymorphic_path(record), notice: "Revisión guardada: #{Review::LABELS[review.status]}."
    else
      redirect_back_or_to polymorphic_path(record), alert: review.errors.full_messages.to_sentence
    end
  end
end
