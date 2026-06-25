class VariantTypesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_variant_type, only: %i[show edit update destroy variants]

  def index
    @variant_types = VariantType.includes(:variants).order(:name)
    @selected = params[:selected_id].present? ? VariantType.find_by(id: params[:selected_id]) : nil
    @stats = {
      total: @variant_types.size,
      variants: Variant.count,
      active: Variant.where(active: true).count
    }
  end

  def show
    respond_to do |format|
      format.html
      format.json { render :show }
    end
  end

  def new
    @variant_type = VariantType.new
  end

  def edit
  end

  def create
    @variant_type = VariantType.new(variant_type_params)
    if @variant_type.save
      redirect_to variant_types_path(selected_id: @variant_type.id),
        notice: "Tipo de variante creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @variant_type.update(variant_type_params)
      redirect_to variant_types_path(selected_id: @variant_type.id),
        notice: "Tipo de variante actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @variant_type.destroy!
    redirect_to variant_types_path, status: :see_other,
      notice: "Tipo de variante eliminado."
  end

  def import
    unless params[:file].present?
      redirect_to variant_types_path, alert: "Por favor, selecciona un archivo CSV."
      return
    end
    ImportVariantTypesJob.perform_later(params[:file].read, current_user.id)
    redirect_to variant_types_path, notice: "Importación iniciada."
  end

  # GET /variant_types/:id/variants.json
  def variants
    render json: @variant_type.variants
      .where(active: true)
      .order(:name)
      .select(:id, :name, :display_name, :code)
  end

  def bulk_move
    variant_ids = Array(params[:variant_ids]).map(&:to_i).uniq
    new_type = VariantType.find(params[:new_type_id])
    moved = 0

    Variant.where(id: variant_ids).each do |variant|
      old_rule_ids = ProductVariantRule
        .where(variant_type_id: variant.variant_type_id).pluck(:id)

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

  def bulk_assign
    variant_ids = Array(params[:variant_ids]).map(&:to_i).uniq
    target_type = VariantType.find(params[:variant_type_id])
    assigned = 0

    Variant.where(id: variant_ids).each do |variant|
      next if variant.variant_type_id == target_type.id

      old_rule_ids = ProductVariantRule
        .where(variant_type_id: variant.variant_type_id).pluck(:id)

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
    @variant_type = VariantType.includes(:variants).find(params[:id])
  end

  def variant_type_params
    params.require(:variant_type).permit(:name, :description, :active, :procurement_strategy, :keep_position)
  end
end
