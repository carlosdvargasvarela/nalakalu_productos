# Genera los CSV de importación para Odoo 19 -> { "archivo.csv" => "contenido" }.
# Orden de importación: 1 categorías, 2 atributos, 3 valores, 4 productos, 5 proveedores por producto.
# Todo lleva ID externo (columna id): los valores se repiten entre atributos, buscarlos por nombre fallaría.
require "csv"

class OdooExportService
  def self.call = new.call

  def call
    canon = {} # ponytail: typos de mayúsculas/espacios en etiquetas ("( Sobre COncreto )") se funden en una
    attr_name = ->(r) do
      next r.variant_type.name if r.label.blank?
      l = r.label.squish.gsub(/\(\s+|\s+\)/) { _1.strip }
      "#{r.variant_type.name} (#{canon[[r.variant_type_id, l.downcase]] ||= l})"
    end
    slug = ->(s) { s.parameterize(separator: "_") }
    attr_xid = ->(n) { "nk_attr_#{slug.(n)}" }
    val_xid = ->(a, v) { "nk_val_#{slug.(a)}_#{slug.(v)}" }

    products = Product.includes(:family, :supplier_items, product_variant_rules: :variant_type).order(:id)
    rules = products.flat_map(&:product_variant_rules)
    vals = Compatibility.where(compatible_type: "ProductVariantRule").includes(:variant).group_by(&:compatible_id)
      .transform_values { |cs| cs.map(&:variant).select(&:active).sort_by(&:id).map(&:seller_name).uniq }

    attrs = rules.map(&attr_name).uniq.sort
    pairs = rules.flat_map { |r| vals.fetch(r.id, []).map { |v| [attr_name.(r), v] } }.uniq.sort
    [attrs.map(&attr_xid), pairs.map { val_xid.(*_1) }, products.map { "nk_prod_#{_1.base_code}" }].each do |x|
      raise "ID externo repetido" if x.uniq.size != x.size
    end

    rows = products.flat_map do |p|
      lines = p.product_variant_rules.filter_map { |r| [attr_xid.(attr_name.(r)), vals[r.id].map { val_xid.(attr_name.(r), _1) }.join(",")] if vals[r.id]&.any? }
      head = ["nk_prod_#{p.base_code}", p.name, p.base_code, "consu", p.family && "nk_categ_#{p.family_id}", p.active ? "True" : "False", p.list_price]
      (lines.presence || [[nil, nil]]).each_with_index.map { |(a, v), i| (i.zero? ? head : [nil] * 7) + [a, v] }
    end

    sinfo = products.flat_map do |p|
      p.supplier_items.includes(:provider).map { |s| ["nk_sinfo_#{s.id}_#{p.id}", s.provider.name, "nk_prod_#{p.base_code}", s.name, s.sku, s.default_cost] }
    end

    {
      "1_product_category.csv" => csv(%w[id name parent_id/id], Family.order(:name).map { ["nk_categ_#{_1.id}", _1.name, "product.product_category_all"] }),
      "2_product_attribute.csv" => csv(%w[id name display_type create_variant], attrs.map { [attr_xid.(_1), _1, "select", "dynamic"] }),
      "3_product_attribute_value.csv" => csv(%w[id attribute_id/id name], pairs.map { |a, v| [val_xid.(a, v), attr_xid.(a), v] }),
      "4_product_template.csv" => csv(%w[id name default_code type categ_id/id active list_price attribute_line_ids/attribute_id/id attribute_line_ids/value_ids/id], rows),
      "5_product_supplierinfo.csv" => csv(%w[id partner_id product_tmpl_id/id product_name product_code price], sinfo)
    }
  end

  private

  def csv(header, rows)
    CSV.generate(write_headers: true, headers: header) { |c| rows.each { c << _1 } }
  end
end
