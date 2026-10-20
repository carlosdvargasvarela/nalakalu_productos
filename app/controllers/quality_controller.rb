# Problemas de datos que conviene resolver antes de importar a Odoo.
# Cada check devuelve [etiqueta, ruta, id] por registro con problema; `kind` (si lo tiene) habilita la selección en masa.
class QualityController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  def index
    @checks = checks
    @selected = params[:check] if @checks.key?(params[:check])
    @results = @checks.transform_values { |c| c[:rows].call }
  end

  private

  def checks
    p = ->(rel) { rel.map { |r| [r.name, product_path(r), r.id] } }
    {
      "products_no_price" => {title: "Productos activos sin precio", kind: "product", rows: -> { p.(Product.where(active: true, list_price: nil).order(:name)) }},
      "products_no_rules" => {title: "Productos sin tipos de variante", kind: "product", rows: -> { p.(Product.where.missing(:product_variant_rules).order(:name)) }},
      "products_no_family" => {title: "Productos sin familia", kind: "product", rows: -> { p.(Product.where(family_id: nil).order(:name)) }},
      "products_dup_code" => {title: "Productos con código base repetido", kind: "product", rows: -> {
        p.(Product.where(base_code: Product.group(:base_code).having("COUNT(*) > 1").select(:base_code)).order(:base_code))
      }},
      "rules_no_variants" => {title: "Tipos de variante de un producto sin ninguna variante asignada", rows: -> {
        used = Compatibility.where(compatible_type: "ProductVariantRule").select(:compatible_id)
        ProductVariantRule.where.not(id: used).includes(:product, :variant_type).map { |r| ["#{r.product.name} → #{r.variant_type.name}", product_path(r.product)] }
      }},
      "variants_dup" => {title: "Variantes con nombre repetido dentro del mismo tipo", kind: "variant", rows: -> {
        Variant.includes(:variant_type).group_by { [_1.variant_type_id, _1.seller_name.squish.downcase] }.values.select { _1.size > 1 }.flatten
          .map { |v| ["#{v.variant_type.name} → #{v.seller_name}", variant_path(v), v.id] }
      }},
      "variants_comma" => {title: "Variantes con coma en el nombre (rompe la importación a Odoo)", kind: "variant", rows: -> {
        Variant.where("name LIKE '%,%' OR display_name LIKE '%,%'").map { |v| [v.seller_name, variant_path(v), v.id] }
      }},
      "types_empty" => {title: "Tipos de variante sin variantes", kind: "variant_type", rows: -> {
        VariantType.where.missing(:variants).order(:name).map { |t| [t.name, variant_type_path(t), t.id] }
      }},
      "variants_no_code" => {title: "Variantes de tipos con código de proveedor propio que no tienen pieza", kind: "variant", rows: -> {
        Variant.joins(:variant_type).where(variant_types: {own_supplier_code: true})
          .where.not(id: SupplierLink.where.not(variant_id: nil).select(:variant_id)).includes(:variant_type).order("variant_types.name", "variants.name")
          .map { |v| ["#{v.variant_type.name} → #{v.seller_name}", variant_path(v), v.id] }
      }},
      "items_no_price" => {title: "Piezas de proveedor sin costo", kind: "supplier_item", rows: -> { SupplierItem.where(default_cost: nil).includes(:provider).map { |s| ["#{s.provider.name} → #{s.name}", supplier_item_path(s), s.id] } }},
      "items_no_sku" => {title: "Piezas de proveedor sin código", kind: "supplier_item", rows: -> { SupplierItem.where(sku: [nil, ""]).includes(:provider).map { |s| ["#{s.provider.name} → #{s.name}", supplier_item_path(s), s.id] } }},
      "items_no_products" => {title: "Piezas de proveedor sin ningún vínculo (producto o variante)", kind: "supplier_item", rows: -> { SupplierItem.where.missing(:supplier_links).includes(:provider).map { |s| ["#{s.provider.name} → #{s.name}", supplier_item_path(s), s.id] } }},
      "providers_no_items" => {title: "Proveedores sin piezas", kind: "provider", rows: -> { Provider.where.missing(:supplier_items).order(:name).map { |pr| [pr.name, provider_path(pr), pr.id] } }}
    }
  end
end
