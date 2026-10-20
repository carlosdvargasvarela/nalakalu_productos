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

    @progress = MODULES.map do |type, (title, path)|
      helpers.review_progress(type.constantize).merge(title: title, path: send(path), type: type)
    end
  end
end
