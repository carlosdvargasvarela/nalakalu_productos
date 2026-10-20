class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  def create
    record = model.find(params.require(:reviewable_id))
    review = record.review || record.build_review
    review.assign_attributes(params.permit(:status, :note).merge(user: current_user))

    if !review.save
      redirect_back_or_to polymorphic_path(record), alert: "Comentario: #{review.errors[:note].to_sentence}"
    elsif params[:advance] == "1"
      go_next(record)
    else
      redirect_back_or_to polymorphic_path(record), notice: "Revisión guardada: #{Review::LABELS[review.status]}."
    end
  end

  # Siguiente registro pendiente después del actual (en orden alfabético, dando la vuelta)
  def next
    go_next(params[:after].present? ? model.find_by(id: params[:after]) : nil)
  end

  private

  def model
    type = params[:reviewable_type] || params[:type]
    raise ActionController::BadRequest unless Reviewable::MODELS.include?(type)
    type.constantize
  end

  def go_next(current)
    ids = model.order(:name, :id).pluck(:id)
    pending = model.review_is("pending").pluck(:id).to_set
    start = current ? ids.index(current.id).to_i + 1 : 0
    target = (ids.rotate(start) - [current&.id]).find { pending.include?(_1) }

    if target
      redirect_to polymorphic_path(model.find(target)), notice: current ? "Guardado. Este es el siguiente pendiente." : nil
    else
      redirect_to polymorphic_path(model), notice: "¡Listo! No quedan registros pendientes en esta sección."
    end
  end
end
