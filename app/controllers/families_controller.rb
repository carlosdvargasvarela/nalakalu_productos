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

    if product_ids.blank?
      redirect_to @family, alert: "No seleccionaste ningún producto."
      return
    end

    products = Product.where(id: product_ids)

    ActiveRecord::Base.transaction do
      products.each do |product|
        # 1. Asignar familia
        product.update!(family_id: @family.id)

        # 2. Borrar reglas actuales del producto (si existieran)
        product.product_variant_rules.destroy_all

        # 3. Clonar las reglas de la familia
        @family.family_variant_rules.each do |fr|
          product.product_variant_rules.create!(
            variant_type_id: fr.variant_type_id,
            position: fr.position,
            required: fr.required,
            separator: fr.separator,
            label: fr.label
          )
        end
      end
    end

    redirect_to @family, notice: "#{products.count} productos asignados y configurados para #{@family.name}."
  end

  def unassign_product
    @family = Family.find(params[:id])
    @product = @family.products.find(params[:product_id])

    @product.update!(family_id: nil)
    redirect_to @family, notice: "#{@product.name} desvinculado de #{@family.name}."
  rescue ActiveRecord::RecordNotFound
    redirect_to @family, alert: "Producto no encontrado en esta familia."
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
