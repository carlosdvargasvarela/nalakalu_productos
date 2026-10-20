class HomeController < ApplicationController
  # Orden recomendado: primero lo que usan los demás, al final los productos.
  MODULES = [
    ["VariantType", "Tipos de variante", :variant_types_path, "bi-tags", "Los grupos de opciones: Telas, Maderas, Piedras…"],
    ["Variant", "Variantes", :variants_path, "bi-palette", "Cada opción concreta dentro de un tipo."],
    ["Family", "Familias", :families_path, "bi-collection", "Grupos de productos parecidos (Mesas de comedor…)."],
    ["Provider", "Proveedores", :providers_path, "bi-building", "A quién se le compra."],
    ["SupplierItem", "Piezas de proveedor", :supplier_items_path, "bi-box-seam", "Lo que se compra: código, costo y dónde se usa."],
    ["Product", "Productos", :products_path, "bi-box", "Lo que se vende. Va al final porque usa todo lo anterior."]
  ].freeze

  def index
    return unless user_signed_in?

    @progress = MODULES.each_with_index.map do |(type, title, path, icon, blurb), i|
      helpers.review_progress(type.constantize).merge(title: title, path: send(path), type: type, icon: icon, blurb: blurb, n: i + 1)
    end
    @next_module = @progress.find { _1[:pending] > 0 }
    @today = Review.where(user_id: current_user.id).where("updated_at >= ?", Time.current.in_time_zone("Central America").beginning_of_day).count
    @to_fix = Review.where(status: "needs_changes").count
  end
end
