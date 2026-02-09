class VariantTypesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_variant_type, only: %i[ show edit update destroy ]

  def index
    @variant_types = VariantType.all
  end

  def show
  end

  def new
    @variant_type = VariantType.new
  end

  def edit
  end

  def create
    @variant_type = VariantType.new(variant_type_params)

    respond_to do |format|
      if @variant_type.save
        format.html { redirect_to @variant_type, notice: "Tipo de variante creado exitosamente." }
        format.json { render :show, status: :created, location: @variant_type }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @variant_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @variant_type.update(variant_type_params)
        format.html { redirect_to @variant_type, notice: "Tipo de variante actualizado exitosamente." }
        format.json { render :show, status: :ok, location: @variant_type }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @variant_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @variant_type.destroy!

    respond_to do |format|
      format.html { redirect_to variant_types_path, status: :see_other, notice: "Tipo de variante eliminado." }
      format.json { head :no_content }
    end
  end

  private
    def set_variant_type
      @variant_type = VariantType.find(params[:id])
    end

    def variant_type_params
      params.require(:variant_type).permit(:name)
    end
end