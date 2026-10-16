# Uso: bin/rails runner scripts/odoo_export.rb  -> tmp/odoo/*.csv
# Importar en Odoo 19 en este orden: 1 categorias, 2 atributos, 3 valores, 4 productos.
# Todo lleva ID externo (columna id): los valores se repiten entre atributos, buscarlos por nombre fallaría.
require "csv"
dir = Rails.root.join("tmp/odoo")
canon = {} # ponytail: typos de mayusculas/espacios en etiquetas ("( Sobre COncreto )") se funden en una
attr_name = ->(r) do
  next r.variant_type.name if r.label.blank?
  l = r.label.squish.gsub(/\(\s+|\s+\)/) { _1.strip }
  "#{r.variant_type.name} (#{canon[[r.variant_type_id, l.downcase]] ||= l})"
end
slug = ->(s) { s.parameterize(separator: "_") }
write = ->(f, header, rows) { CSV.open(dir.join(f), "w", write_headers: true, headers: header) { |c| rows.each { c << _1 } } }
attr_xid = ->(n) { "nk_attr_#{slug.(n)}" }
val_xid = ->(a, v) { "nk_val_#{slug.(a)}_#{slug.(v)}" }

products = Product.includes(:family, product_variant_rules: :variant_type).order(:id)
rules = products.flat_map(&:product_variant_rules)
vals = Compatibility.where(compatible_type: "ProductVariantRule").includes(:variant).group_by(&:compatible_id)
          .transform_values { |cs| cs.map(&:variant).select(&:active).sort_by(&:id).map(&:seller_name).uniq }

attrs = rules.map(&attr_name).uniq.sort
pairs = rules.flat_map { |r| vals.fetch(r.id, []).map { |v| [attr_name.(r), v] } }.uniq.sort
[attrs.map(&attr_xid), pairs.map { val_xid.(*_1) }, products.map { "nk_prod_#{_1.base_code}" }].each { |x| raise "ID externo repetido" if x.uniq.size != x.size }

write.("1_product_category.csv", %w[id name parent_id/id], Family.order(:name).map { ["nk_categ_#{_1.id}", _1.name, "product.product_category_all"] })
write.("2_product_attribute.csv", %w[id name display_type create_variant], attrs.map { [attr_xid.(_1), _1, "select", "dynamic"] })
write.("3_product_attribute_value.csv", %w[id attribute_id/id name], pairs.map { |a, v| [val_xid.(a, v), attr_xid.(a), v] })

rows = products.flat_map do |p|
  lines = p.product_variant_rules.filter_map { |r| [attr_xid.(attr_name.(r)), vals[r.id].map { val_xid.(attr_name.(r), _1) }.join(",")] if vals[r.id]&.any? }
  head = ["nk_prod_#{p.base_code}", p.name, p.base_code, "consu", p.family && "nk_categ_#{p.family_id}", p.active ? "True" : "False"]
  (lines.presence || [[nil, nil]]).each_with_index.map { |(a, v), i| (i.zero? ? head : [nil] * 6) + [a, v] }
end
write.("4_product_template.csv", %w[id name default_code type categ_id/id active attribute_line_ids/attribute_id/id attribute_line_ids/value_ids/id], rows)

bad = Variant.where("name like '%,%' or display_name like '%,%'").pluck(:id, :name)
puts "productos=#{products.size} filas=#{rows.size} valores con coma=#{bad.inspect}"
