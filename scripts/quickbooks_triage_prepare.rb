# Lee el Excel de triaje (ya llenado) y genera el JSON de decisiones para quickbooks_triage_apply.rb. Omite la hoja «Léeme».
# Uso: bin/rails runner scripts/quickbooks_triage_prepare.rb tmp/triaje_quickbooks.xlsx tmp/triaje_decisiones.json
require "roo"
xlsx, out = ARGV
book = Roo::Excelx.new(xlsx)
d = {"cambiar" => [], "ocultar" => [], "eliminar" => [], "agregar" => [], "revisar" => []}
add = lambda do |sheet, family_col:|
  s = book.sheet(sheet)
  hdr = s.row(1).map(&:to_s)
  di = hdr.index("Decisión")
  (2..s.last_row).each do |i|
    r = s.row(i)
    next unless r[di].to_s.strip == "Agregar"
    d["agregar"] << {"code" => r[0].to_s.strip, "name" => r[1].to_s, "price" => r[2].to_s, "family" => family_col ? r[family_col].to_s : nil}
  end
end
add.("Candidatos a catálogo", family_col: 3)
add.("Trabajos a medida", family_col: nil)
add.("Códigos raros", family_col: nil)

s = book.sheet("Nuestros sin QuickBooks")
hdr = s.row(1).map(&:to_s)
di, new_i = hdr.index("Decisión"), hdr.index("Código en QuickBooks")
(2..s.last_row).each do |i|
  r = s.row(i)
  code, dec = r[0].to_s.strip, r[di].to_s.strip
  case dec
  when /\ACambiar/ then d["cambiar"] << {"code" => code, "new_code" => r[new_i].to_s.strip} if r[new_i].to_s.strip.present?
  when /\AOcultar/ then d["ocultar"] << code
  when /\AEliminar/ then d["eliminar"] << code
  when /\ARevisar/ then d["revisar"] << code
  end
end
File.write(out, JSON.generate(d))
puts d.transform_values(&:size).inspect + " → #{out}"
