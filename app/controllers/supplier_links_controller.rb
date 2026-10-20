class SupplierLinksController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  def create
    link = SupplierLink.new(params.require(:supplier_link).permit(:supplier_item_id, :product_id, :variant_id))
    flash_key = link.save ? :notice : :alert
    redirect_to return_path(supplier_item_path(link.supplier_item_id)), status: :see_other,
      flash_key => (link.persisted? ? "Vínculo agregado. Puedes deshacerlo desde el Historial." : link.errors.full_messages.to_sentence)
  end

  def destroy
    link = SupplierLink.find(params[:id])
    link.destroy
    redirect_to return_path(supplier_item_path(link.supplier_item_id)), status: :see_other, notice: "Vínculo eliminado."
  end

  private

  # Vuelve a la pantalla desde la que se vinculó (solo rutas internas)
  def return_path(default)
    to = params[:return_to].to_s
    (to.start_with?("/") && !to.start_with?("//")) ? to : default
  end
end
