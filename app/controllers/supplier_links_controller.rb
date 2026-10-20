class SupplierLinksController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  def create
    link = SupplierLink.new(params.require(:supplier_link).permit(:supplier_item_id, :product_id, :variant_id))
    flash_key = link.save ? :notice : :alert
    redirect_to supplier_item_path(link.supplier_item_id), flash_key => (link.persisted? ? "Vínculo agregado." : link.errors.full_messages.to_sentence)
  end

  def destroy
    link = SupplierLink.find(params[:id])
    link.destroy
    redirect_to supplier_item_path(link.supplier_item_id), notice: "Vínculo eliminado."
  end
end
