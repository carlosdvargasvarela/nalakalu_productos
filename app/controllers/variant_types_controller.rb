# app/controllers/variant_types_controller.rb
class VariantTypesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_variant_type, only: %i[show edit update destroy]

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

  def import
    unless params[:file].present?
      redirect_to variant_types_path, alert: "Por favor, selecciona un archivo CSV."
      return
    end
    csv_content = params[:file].read
    ImportVariantTypesJob.perform_later(csv_content, current_user.id)
    redirect_to variant_types_path, notice: "Importación de tipos de variante iniciada."
  end

  # Mover múltiples variantes a otro tipo (desde variant_types/show)
  def bulk_move
    variant_ids = Array(params[:variant_ids]).map(&:to_i).uniq
    new_type = VariantType.find(params[:new_type_id])
    variants = Variant.where(id: variant_ids)
    moved = 0

    variants.each do |variant|
      old_rule_ids = ProductVariantRule
        .where(variant_type_id: variant.variant_type_id)
        .pluck(:id)

      Compatibility.where(
        variant_id: variant.id,
        compatible_type: "ProductVariantRule",
        compatible_id: old_rule_ids
      ).destroy_all

      if variant.update(variant_type: new_type)
        ProductVariantRule.where(variant_type_id: new_type.id).each do |rule|
          Compatibility.find_or_create_by!(
            variant_id: variant.id,
            compatible_type: "ProductVariantRule",
            compatible_id: rule.id
          )
        end
        moved += 1
      end
    end

    redirect_to variant_type_path(new_type),
      notice: "#{moved} variante(s) movidas a '#{new_type.name}'."
  end

  # Asignar variantes huérfanas a un tipo (desde variants/index)
  def bulk_assign
    variant_ids = Array(params[:variant_ids]).map(&:to_i).uniq
    target_type = VariantType.find(params[:variant_type_id])
    variants = Variant.where(id: variant_ids)
    assigned = 0

    variants.each do |variant|
      next if variant.variant_type_id == target_type.id

      old_rule_ids = ProductVariantRule
        .where(variant_type_id: variant.variant_type_id)
        .pluck(:id)

      Compatibility.where(
        variant_id: variant.id,
        compatible_type: "ProductVariantRule",
        compatible_id: old_rule_ids
      ).destroy_all

      if variant.update(variant_type: target_type)
        ProductVariantRule.where(variant_type_id: target_type.id).each do |rule|
          Compatibility.find_or_create_by!(
            variant_id: variant.id,
            compatible_type: "ProductVariantRule",
            compatible_id: rule.id
          )
        end
        assigned += 1
      end
    end

    redirect_to variant_type_path(target_type),
      notice: "#{assigned} variante(s) asignadas a '#{target_type.name}'."
  end

  private

  def set_variant_type
    @variant_type = VariantType.find(params[:id])
  end

  def variant_type_params
    params.require(:variant_type).permit(:name)
  end
end
