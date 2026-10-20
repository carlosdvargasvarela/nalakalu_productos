# Convierte el export de QuickBooks (Excel) + los contactos de Odoo en un JSON para quickbooks_import.rb.
# Uso: bin/rails runner scripts/quickbooks_prepare.rb "tmp/Items - Quickbooks.xlsx" "<Contactos_Odoo_Proveedores.xlsx>" tmp/quickbooks_payload.json
require "roo"
items_path, contacts_path, out_path = ARGV
sheet = Roo::Excelx.new(items_path).sheet("Hoja1")
keys = %w[item desc type cost price tax qoh qso reorder qpo umset um vendor]
rows = (2..sheet.last_row).map { |i| keys.zip(sheet.row(i)).to_h.slice("item", "desc", "type", "cost", "price", "um", "vendor").transform_values { _1.to_s } }

contacts = Roo::Excelx.new(contacts_path).sheet("Proveedores")
header = contacts.row(1).map { _1.to_s.strip }
odoo = (2..contacts.last_row).map { contacts.row(_1)[header.index("Nombre")].to_s.strip }.reject(&:empty?)

# ponytail: normalización simple (sin S.A./puntos/asteriscos); si dos nombres de Odoo normalizan igual, no se adivina
norm = ->(t) { I18n.transliterate(t.to_s).downcase.gsub(/[*.,]/, " ").gsub(/\b(s a|sa|s r l|srl|ltda|ltd|sociedad anonima|s p a|spa|pty|inc|llc)\b/, " ").gsub(/[^a-z0-9]+/, " ").squish }
by_norm = odoo.group_by { norm.(_1) }
map = {}
rows.map { _1["vendor"] }.reject(&:empty?).uniq.each do |v|
  map[v] = if odoo.include?(v) then v
  elsif (c = by_norm[norm.(v)]) && c.size == 1 then c.first
  end
end
File.write(out_path, JSON.generate({rows: rows, vendor_map: map.compact}))
puts "Filas: #{rows.size}. Proveedores: #{map.size} (con equivalente en Odoo: #{map.compact.size}). Archivo: #{out_path}"
