# Problemas de datos que conviene resolver antes de importar a Odoo.
# Cada check devuelve [etiqueta, ruta] por registro con problema.
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
    p = ->(rel) { rel.map { |r| [r.name, product_path(r)] } }
    {
      "products_no_price" => {title: "Productos activos sin precio", rows: -> { p.(Product.where(active: true, list_price: nil).order(:name)) }},
      "products_no_rules" => {title: "Productos sin tipos de variante", rows: -> { p.(Product.where.missing(:product_variant_rules).order(:name)) }},
      "products_no_family" => {title: "Productos sin familia", rows: -> { p.(Product.where(family_id: nil).order(:name)) }},
      "products_dup_code" => {title: "Productos con código base repetido", rows: -> {
        p.(Product.where(base_code: Product.group(:base_code).having("COUNT(*) > 1").select(:base_code)).order(:base_code))
      }},
      "rules_no_variants" => {title: "Tipos de variante de un producto sin ninguna variante asignada", rows: -> {
        used = Compatibility.where(compatible_type: "ProductVariantRule").select(:compatible_id)
        ProductVariantRule.where.not(id: used).includes(:product, :variant_type).map { |r| ["#{r.product.name} → #{r.variant_type.name}", product_path(r.product)] }
      }},
      "variants_dup" => {title: "Variantes con nombre repetido dentro del mismo tipo", rows: -> {
        Variant.includes(:variant_type).group_by { [_1.variant_type_id, _1.seller_name.squish.downcase] }.values.select { _1.size > 1 }.flatten
          .map { |v| ["#{v.variant_type.name} → #{v.seller_name}", variant_path(v)] }
      }},
      "variants_comma" => {title: "Variantes con coma en el nombre (rompe la importación a Odoo)", rows: -> {
        Variant.where("name LIKE '%,%' OR display_name LIKE '%,%'").map { |v| [v.seller_name, variant_path(v)] }
      }},
      "types_empty" => {title: "Tipos de variante sin variantes", rows: -> {
        VariantType.where.missing(:variants).order(:name).map { |t| [t.name, variant_type_path(t)] }
      }},
      "items_no_price" => {title: "Piezas de proveedor sin costo", rows: -> { SupplierItem.where(default_cost: nil).includes(:provider).map { |s| ["#{s.provider.name} → #{s.name}", supplier_item_path(s)] } }},
      "items_no_sku" => {title: "Piezas de proveedor sin código", rows: -> { SupplierItem.where(sku: [nil, ""]).includes(:provider).map { |s| ["#{s.provider.name} → #{s.name}", supplier_item_path(s)] } }},
      "items_no_products" => {title: "Piezas de proveedor sin producto relacionado", rows: -> { SupplierItem.where.missing(:products).includes(:provider).map { |s| ["#{s.provider.name} → #{s.name}", supplier_item_path(s)] } }},
      "providers_no_items" => {title: "Proveedores sin piezas", rows: -> { Provider.where.missing(:supplier_items).order(:name).map { |pr| [pr.name, provider_path(pr)] } }}
    }
  end
end
