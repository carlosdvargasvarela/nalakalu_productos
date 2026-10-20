class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  # Registros marcados «requiere cambios», con el comentario del revisor
  def index
    @reviews = Review.where(status: "needs_changes").includes(:user, :reviewable).order(updated_at: :desc)
    @reviews = @reviews.where(reviewable_type: params[:type]) if Reviewable::MODELS.include?(params[:type])
    # la selección en masa solo se ofrece cuando la lista es de un único tipo de registro
    @bulk_kind = params[:type].presence && Reviewable::MODELS.include?(params[:type]) ? params[:type].underscore : nil
    @all_ids = @reviews.map(&:reviewable_id) if @bulk_kind
  end

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

  # Registro anterior en el orden de la lista (sin importar su estado), para corregir un error al avanzar
  def prev
    current = model.find(params[:before])
    ids = model.order(:name, :id).pluck(:id)
    i = ids.index(current.id).to_i
    if i > 0
      redirect_to polymorphic_path(model.find(ids[i - 1]))
    else
      redirect_to polymorphic_path(model), notice: "Este es el primero de la lista."
    end
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
