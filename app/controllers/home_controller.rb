class HomeController < ApplicationController
  MODULES = {
    "Family" => ["Familias", :families_path],
    "Product" => ["Productos", :products_path],
    "VariantType" => ["Tipos de variante", :variant_types_path],
    "Variant" => ["Variantes", :variants_path],
    "Provider" => ["Proveedores", :providers_path],
    "SupplierItem" => ["Piezas de proveedor", :supplier_items_path]
  }.freeze

  def index
    return unless user_signed_in?

    by_status = Review.group(:reviewable_type, :status).count
    @progress = MODULES.map do |type, (title, path)|
      total = type.constantize.count
      approved = by_status[[type, "approved"]].to_i
      {title: title, path: send(path), total: total, approved: approved,
       needs_changes: by_status[[type, "needs_changes"]].to_i, pending: total - approved - by_status[[type, "needs_changes"]].to_i}
    end
  end
end
