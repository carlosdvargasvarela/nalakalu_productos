class RecommendationsController < ApplicationController
  before_action :authenticate_user!, only: %i[index approve reject]
  before_action :authorize_admin!, only: %i[index approve reject]
  before_action :set_recommendation, only: %i[approve reject]

  def index
    @pending  = Recommendation.pending.includes(:variant_type, :product).ordered
    @approved = Recommendation.where(status: "approved").includes(:variant_type, :product).ordered
    @rejected = Recommendation.where(status: "rejected").includes(:variant_type, :product).ordered
  end

  def check_existing
    variant_type_id = params[:variant_type_id].to_i
    name = params[:name].to_s.strip.downcase

    variants = Variant.where(variant_type_id: variant_type_id, active: true).order(:name)

    exact_match = name.present? && variants.any? { |v|
      v.name.downcase == name || v.display_name.to_s.downcase == name
    }

    render json: {
      variants: variants.map { |v| { id: v.id, name: v.display_name.presence || v.name } },
      exact_match: exact_match
    }
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
