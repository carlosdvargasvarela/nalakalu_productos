# Uso: bin/rails runner scripts/odoo_export.rb  -> tmp/odoo/*.csv
# Importar en Odoo 19 en este orden: 1 categorias, 2 atributos, 3 valores, 4 productos.
require "csv"
dir = Rails.root.join("tmp/odoo")
attr_name = ->(r) { r.label.present? ? "#{r.variant_type.name} (#{r.label})" : r.variant_type.name }
write = ->(f, header, rows) { CSV.open(dir.join(f), "w", write_headers: true, headers: header) { |c| rows.each { c << _1 } } }

products = Product.includes(:family, product_variant_rules: :variant_type).order(:id)
rules = products.flat_map(&:product_variant_rules)
vals = Compatibility.where(compatible_type: "ProductVariantRule").includes(:variant).group_by(&:compatible_id)
          .transform_values { |cs| cs.map(&:variant).select(&:active).sort_by(&:id).map(&:seller_name).uniq }

write.("1_product_category.csv", %w[name parent_id], Family.order(:name).map { [_1.name, "All"] })
write.("2_product_attribute.csv", %w[name display_type create_variant],
  rules.map(&attr_name).uniq.sort.map { [_1, "select", "dynamic"] })
write.("3_product_attribute_value.csv", %w[attribute_id name],
  rules.flat_map { |r| vals.fetch(r.id, []).map { |v| [attr_name.(r), v] } }.uniq.sort)

rows = products.flat_map do |p|
  lines = p.product_variant_rules.filter_map { |r| [attr_name.(r), vals[r.id].join(",")] if vals[r.id]&.any? }
  head = [p.name, p.base_code, "consu", p.family&.name, p.active ? "True" : "False"]
  (lines.presence || [[nil, nil]]).each_with_index.map { |(a, v), i| (i.zero? ? head : [nil] * 5) + [a, v] }
end
write.("4_product_template.csv", %w[name default_code type categ_id active attribute_line_ids/attribute_id attribute_line_ids/value_ids], rows)

bad = Variant.where("name like '%,%' or display_name like '%,%'").pluck(:id, :name)
puts "productos=#{products.size} filas=#{rows.size} valores con coma (rompen import)=#{bad.inspect}"
