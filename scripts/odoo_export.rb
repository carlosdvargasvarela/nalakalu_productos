# Uso: bin/rails runner scripts/odoo_export.rb  -> tmp/odoo/*.csv (lo mismo que descarga la web en /odoo_exports)
dir = Rails.root.join("tmp/odoo")
FileUtils.mkdir_p(dir)
OdooExportService.call.each { |f, body| File.write(dir.join(f), body) }
