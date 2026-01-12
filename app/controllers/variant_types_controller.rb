class VariantTypesController < ApplicationController
  before_action :set_variant_type, only: %i[ show edit update destroy ]

  # GET /variant_types or /variant_types.json
  def index
    @variant_types = VariantType.all
  end

  # GET /variant_types/1 or /variant_types/1.json
  def show
  end

  # GET /variant_types/new
  def new
    @variant_type = VariantType.new
  end

  # GET /variant_types/1/edit
  def edit
  end

  # POST /variant_types or /variant_types.json
  def create
    @variant_type = VariantType.new(variant_type_params)

    respond_to do |format|
      if @variant_type.save
        format.html { redirect_to @variant_type, notice: "Variant type was successfully created." }
        format.json { render :show, status: :created, location: @variant_type }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @variant_type.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /variant_types/1 or /variant_types/1.json
  def update
    respond_to do |format|
      if @variant_type.update(variant_type_params)
        format.html { redirect_to @variant_type, notice: "Variant type was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @variant_type }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @variant_type.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /variant_types/1 or /variant_types/1.json
  def destroy
    @variant_type.destroy!

    respond_to do |format|
      format.html { redirect_to variant_types_path, notice: "Variant type was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_variant_type
      @variant_type = VariantType.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def variant_type_params
      params.require(:variant_type).permit(:name)
    end
end
