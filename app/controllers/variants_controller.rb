class VariantsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_variant, only: %i[ show edit update destroy ]

  def index
    @variants = Variant.all.includes(:variant_type, :provider)
  end

  def show
  end

  def new
    @variant = Variant.new
  end

  def edit
  end

  def create
    @variant = Variant.new(variant_params)

    respond_to do |format|
      if @variant.save
        format.html { redirect_to @variant, notice: "Variante creada exitosamente." }
        format.json { render :show, status: :created, location: @variant }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @variant.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @variant.update(variant_params)
        format.html { redirect_to @variant, notice: "Variante actualizada exitosamente." }
        format.json { render :show, status: :ok, location: @variant }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @variant.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @variant.destroy!

    respond_to do |format|
      format.html { redirect_to variants_path, status: :see_other, notice: "Variante eliminada." }
      format.json { head :no_content }
    end
  end

  private
    def set_variant
      @variant = Variant.find(params[:id])
    end

    def variant_params
      params.require(:variant).permit(
        :variant_type_id,
        :provider_id,
        :name,
        :code,
        :provider_sku,
        :cost,
        :active,
        compatible_variant_ids: []
      )
    end
end