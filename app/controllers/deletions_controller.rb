# Confirmación de borrado: muestra qué se pierde (con conteos) y ofrece ocultar en lugar de eliminar.
class DeletionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :load_record

  KINDS = {"product" => Product, "variant" => Variant, "variant_type" => VariantType, "family" => Family,
           "provider" => Provider, "supplier_item" => SupplierItem}.freeze

  def new
    @impact = DeleteImpact.for(@record)
  end

  def destroy
    name = record_name
    if @record.destroy
      redirect_to polymorphic_path(@record.class), status: :see_other,
        notice: "«#{name}» eliminado. Puedes deshacerlo desde el Historial."
    else
      redirect_to confirm_delete_path(params[:kind], @record), status: :see_other, alert: @record.errors.full_messages.to_sentence.presence || "No se pudo eliminar."
    end
  end

  def hide
    @record.update!(active: false)
    redirect_to @record, notice: "«#{record_name}» quedó oculto (inactivo). No se borró nada."
  end

  private

  def load_record
    @record = KINDS.fetch(params[:kind]).find(params[:id])
  end

  def record_name
    @record.try(:seller_name) || @record.name
  end
end
