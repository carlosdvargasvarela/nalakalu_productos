class RecommendationsController < ApplicationController
  before_action :authenticate_user!, only: %i[index approve reject]
  before_action :authorize_admin!, only: %i[index approve reject]
  before_action :set_recommendation, only: %i[approve reject]

  def index
    @pending = Recommendation.pending.includes(:variant_type, :product).ordered
    @resolved = Recommendation.resolved.includes(:variant_type, :product).ordered
  end

  def new
    @recommendation = Recommendation.new
    @variant_types = VariantType.active.order(:name)
    @products = Product.where(active: true).order(:name)
  end

  def create
    @recommendation = Recommendation.new(recommendation_params)
    if @recommendation.save
      redirect_to new_sale_path, notice: "Recomendación enviada. ¡Gracias!"
    else
      @variant_types = VariantType.active.order(:name)
      @products = Product.where(active: true).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def approve
    @recommendation.approve!
    redirect_to recommendations_path, notice: "Recomendación aprobada y aplicada correctamente."
  rescue => e
    redirect_to recommendations_path, alert: "Error al aprobar: #{e.message}"
  end

  def reject
    @recommendation.update!(status: "rejected")
    redirect_to recommendations_path, notice: "Recomendación rechazada."
  rescue => e
    redirect_to recommendations_path, alert: "Error al rechazar: #{e.message}"
  end

  private

  def set_recommendation
    @recommendation = Recommendation.find(params[:id])
  end

  def recommendation_params
    params.require(:recommendation).permit(
      :recommendation_type, :variant_type_id, :product_id,
      :suggested_variant_name, :suggested_variant_code,
      :requester_name, :notes
    )
  end
end
