class FamiliesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_family, only: %i[show edit update destroy]

  def index
    @families = Family.all.includes(:family_variant_rules)
  end

  def show
  end

  def new
    @family = Family.new
  end

  def edit
  end

  def create
    @family = Family.new(family_params)
    if @family.save
      redirect_to families_path, notice: "Familia creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @family.update(family_params)
      redirect_to families_path, notice: "Familia actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @family.destroy!
    redirect_to families_path, notice: "Familia eliminada."
  end

  def assign_products
    @family = Family.find(params[:id])
    product_ids = params[:product_ids]

    if product_ids.present?
      Product.where(id: product_ids).update_all(family_id: @family.id)
      redirect_to @family, notice: "#{product_ids.count} productos asignados a #{@family.name}."
    else
      redirect_to @family, alert: "No seleccionaste ningún producto."
    end
  end

  private

  def set_family
    @family = Family.find(params[:id])
  end

  def family_params
    params.require(:family).permit(
      :name, :description, :active,
      family_variant_rules_attributes: [:id, :variant_type_id, :position, :required, :separator, :label, :_destroy]
    )
  end
end
