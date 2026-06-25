class FamiliesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_family, only: %i[show edit update destroy assign_products unassign_product]

  def index
    @families = Family.all.includes(:products, family_variant_rules: :variant_type)
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
    product_ids = params[:product_ids]

    if product_ids.blank?
      redirect_to @family, alert: "No seleccionaste ningún producto."
      return
    end

    products = Product.where(id: product_ids)
    count = 0

    ActiveRecord::Base.transaction do
      products.each do |product|
        # El callback sync_variant_rules_from_family se dispara automáticamente
        # al cambiar family_id, clonando las reglas y creando compatibilidades
        product.update!(family_id: @family.id)
        count += 1
      end
    end

    redirect_to @family, notice: "#{count} productos asignados a #{@family.name}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @family, alert: "Error al asignar productos: #{e.message}"
  end

  def unassign_product
    @product = @family.products.find(params[:product_id])

    ActiveRecord::Base.transaction do
      # Limpiar compatibilidades generadas por las reglas de la familia
      rule_ids = @product.product_variant_rules.pluck(:id)
      Compatibility.where(compatible_type: "ProductVariantRule", compatible_id: rule_ids).destroy_all

      # Borrar las reglas del producto
      @product.product_variant_rules.destroy_all

      # Desvincular de la familia
      @product.update!(family_id: nil)
    end

    redirect_to @family, notice: "#{@product.name} desvinculado y reglas limpiadas."
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
      family_variant_rules_attributes: [
        :id, :variant_type_id, :position, :required, :separator, :label, :_destroy
      ]
    )
  end
end
