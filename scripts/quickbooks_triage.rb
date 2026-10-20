# Excel para que el negocio decida qué hacer con lo que no coincide entre QuickBooks y el catálogo.
# Uso: bin/rails runner scripts/quickbooks_triage.rb  ->  tmp/triaje_quickbooks.xlsx
# No modifica nada: solo lee qb_items y products.
qb = QbItem.all.to_a
abort "Primero carga QuickBooks (scripts/quickbooks_import.rb)." if qb.empty?

ours = Product.includes(:family).to_a
our_codes = ours.map(&:base_code).to_set
family_by_series = ours.group_by { _1.base_code.to_s[0, 3] }.transform_values { |ps| ps.map { _1.family&.name }.compact.tally.max_by(&:last)&.first }
nine = qb.select { _1.code.match?(/\A\d{9}\z/) }
missing_here = nine.reject { our_codes.include?(_1.code) }
custom = missing_here.select { _1.code.start_with?("0099") }
candidates = (missing_here - custom).reject { _1.description.blank? && _1.price.to_f.zero? }
weird = qb.select { _1.item_type == "Inventory Part" && !_1.code.match?(/\A\d{9}\z/) && !_1.code.match?(/\A[A-Za-z]{3}/) }
clean = ->(t) { I18n.transliterate(t.to_s).downcase.gsub(/[^a-z0-9]+/, " ").squish }
qb_by_name = qb.group_by { clean.(_1.description) }
not_in_qb = ours.reject { |p| QbItem.exists?(code: p.base_code) }

pkg = Axlsx::Package.new
wb = pkg.workbook
head = wb.styles.add_style(b: true, bg_color: "1F4E79", fg_color: "FFFFFF", alignment: {vertical: :center, wrap_text: true})
decide = wb.styles.add_style(bg_color: "FFF2CC", border: {style: :thin, color: "BF9000"})
money = wb.styles.add_style(format_code: "#,##0.00")
wrap = wb.styles.add_style(alignment: {wrap_text: true, vertical: :top})

sheet = lambda do |name, headers, widths, rows, choices: nil, decision_col: nil, default: nil|
  wb.add_worksheet(name: name) do |s|
    s.add_row headers, style: head, height: 32
    types = headers.map { _1.include?("Código") ? :string : nil } # los códigos son texto: conservan los ceros a la izquierda
    rows.each { |r| s.add_row(r, types: types) }
    s.column_widths(*widths)
    s.sheet_view.pane { |p| p.state = :frozen; p.y_split = 1; p.top_left_cell = "A2" }
    s.auto_filter = "A1:#{(64 + headers.size).chr}#{rows.size + 1}"
    if decision_col && rows.any?
      col = (64 + decision_col).chr
      (2..rows.size + 1).each { |i| s["#{col}#{i}"].style = decide }
      s.add_data_validation("#{col}2:#{col}#{rows.size + 1}", type: :list, formula1: %("#{choices.join(",")}"), allowBlank: true,
        errorTitle: "Opción no válida", error: "Elige una de la lista.", showErrorMessage: true)
    end
  end
end

wb.add_worksheet(name: "Léeme") do |s|
  s.add_row ["Triaje de QuickBooks vs catálogo"], style: wb.styles.add_style(b: true, sz: 14)
  s.add_row []
  [
    "QuickBooks es la fuente de verdad. Esta hoja resume lo que NO coincide con el catálogo de la app, para decidir qué se hace.",
    "Nada de lo que aquí se decida se aplica solo: cuando el archivo vuelva con las decisiones, se cargan los cambios con vista previa y se pueden deshacer.",
    "Llena la columna amarilla «Decisión» de cada hoja (lista desplegable). Los nombres ya vienen sin los puntos que QuickBooks agrega.",
    "Los precios son los de QuickBooks, SIN IVA.",
    "",
    "Hojas:",
    "  • Candidatos a catálogo (#{candidates.size}): productos de venta que están en QuickBooks y no en el catálogo. Decide: Agregar / Ignorar / Revisar.",
    "  • Nuestros sin QuickBooks (#{not_in_qb.size}): productos del catálogo cuyo código no existe en QuickBooks. Decide qué hacer con cada uno.",
    "  • Trabajos a medida (#{custom.size}): serie 0099…, pedidos únicos de clientes. Vienen marcados «Ignorar» (no entran al catálogo); cambia solo las excepciones.",
    "  • Códigos raros (#{weird.size}): ítems de inventario con un código que no sigue ningún patrón.",
    "",
    "Generado: #{Time.current.in_time_zone("Central America").strftime("%d/%m/%Y %H:%M")}"
  ].each { s.add_row [_1], style: wrap }
  s.column_widths 140
end

sheet.("Candidatos a catálogo", ["Código", "Nombre (sin puntos)", "Precio sin IVA", "Familia sugerida", "Decisión", "Comentario"], [14, 58, 16, 30, 16, 40],
  candidates.sort_by(&:code).map { |q| [q.code, q.name, q.price&.to_f, family_by_series[q.code[0, 3]], nil, nil] },
  choices: %w[Agregar Ignorar Revisar], decision_col: 5)

sheet.("Nuestros sin QuickBooks", ["Código nuestro", "Nombre nuestro", "Activo", "Familia", "Qué encontré en QuickBooks", "Código en QuickBooks", "Nombre en QuickBooks", "Precio QB sin IVA", "Decisión", "Comentario"],
  [15, 48, 9, 28, 38, 16, 44, 16, 24, 40],
  not_in_qb.sort_by(&:base_code).map { |p|
    same = qb_by_name[clean.(p.name)]&.first
    like = same || qb.find { _1.code.match?(/\A\d{9}\z/) && _1.code[0, 6] == p.base_code[0, 6] && clean.(_1.description).split.first(3) == clean.(p.name).split.first(3) }
    found = same ? "Mismo nombre con otro código" : (like ? "Parecido en la misma serie" : "No aparece")
    [p.base_code, p.name, p.active ? "sí" : "no", p.family&.name, found, like&.code, like&.name, like&.price&.to_f, nil, nil]
  },
  choices: ["Cambiar al código de QuickBooks", "Mantener (crear en QuickBooks)", "Ocultar (inactivo)", "Eliminar", "Revisar"], decision_col: 9)

sheet.("Trabajos a medida", ["Código", "Nombre (sin puntos)", "Precio sin IVA", "Decisión", "Comentario"], [14, 66, 16, 16, 40],
  custom.sort_by(&:code).map { |q| [q.code, q.name, q.price&.to_f, "Ignorar", nil] },
  choices: %w[Ignorar Agregar Revisar], decision_col: 4)

sheet.("Códigos raros", ["Código", "Nombre (sin puntos)", "Precio sin IVA", "Decisión", "Comentario"], [20, 60, 16, 16, 40],
  weird.sort_by(&:code).map { |q| [q.code, q.name, q.price&.to_f, nil, nil] }, choices: %w[Agregar Ignorar Revisar], decision_col: 4)

# formato de moneda en las columnas de precio
wb.worksheets.each do |ws|
  idx = ws.rows.first&.cells&.index { _1.value.to_s.start_with?("Precio") }
  next unless idx
  ws.rows.to_a.drop(1).each { |r| r.cells[idx].style = money if r.cells[idx] }
end

out = Rails.root.join("tmp/triaje_quickbooks.xlsx")
pkg.serialize(out.to_s)
puts "Archivo: #{out}  (#{(File.size(out) / 1024.0).round} KB)"
puts "Candidatos: #{candidates.size} · Nuestros sin QB: #{not_in_qb.size} · A medida: #{custom.size} · Raros: #{weird.size}"
