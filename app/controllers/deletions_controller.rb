# Confirmación de borrado: muestra qué se pierde (con conteos) y ofrece ocultar en lugar de eliminar.
class DeletionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :load_record

  KINDS = {"product" => Product, "variant" => Variant, "variant_type" => VariantType, "family" => Family,
           "provider" => Provider, "supplier_item" => SupplierItem}.freeze

  def new
    @impact = impact_of(@record)
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

  # [[texto, cantidad, se_pierde?]]
  def impact_of(r)
    case r
    when Product
      rules = r.product_variant_rules
      [["reglas de código (tipos de variante) del producto", rules.count, true],
        ["variantes permitidas dentro de esas reglas", Compatibility.where(compatible_type: "ProductVariantRule", compatible_id: rules.select(:id)).count, true],
        ["vínculos con piezas de proveedor", r.supplier_links.count, true]]
    when Variant
      [["compatibilidades con productos y otras variantes", r.compatibilities.count + r.reverse_compatibilities.count, true],
        ["productos donde está disponible", r.compatible_product_ids.size, false],
        ["vínculos con piezas de proveedor", r.supplier_links.count, true]]
    when VariantType
      [["variantes que se eliminan junto con el tipo", r.variants.count, true],
        ["productos que usan este tipo en su código (perderán ese paso)", r.product_variant_rules.count, true],
        ["familias que lo usan", r.family_variant_rules.count, true]]
    when Family
      [["productos que quedarán sin familia (no se borran)", r.products.count, false],
        ["reglas de código de la familia", r.family_variant_rules.count, true]]
    when Provider
      items = r.supplier_items
      [["piezas de proveedor que se eliminan", items.count, true],
        ["vínculos de esas piezas con productos y variantes", SupplierLink.where(supplier_item_id: items.select(:id)).count, true],
        ["órdenes de compra (impiden eliminarlo)", r.purchase_orders.count, r.purchase_orders.count > 0]]
    when SupplierItem
      [["vínculos con productos y variantes", r.supplier_links.count, true]]
    end
  end
end
