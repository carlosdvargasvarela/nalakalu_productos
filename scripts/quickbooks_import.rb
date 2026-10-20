# Carga y concilia el export de QuickBooks. Lee el JSON de quickbooks_prepare.rb por stdin.
#   Local:     bin/rails runner scripts/quickbooks_import.rb < tmp/quickbooks_payload.json
#   Heroku:    heroku run --no-tty -a nalakalu-productos "rails runner scripts/quickbooks_import.rb" < tmp/quickbooks_payload.json
# DRY_RUN=1 ejecuta todo y revierte al final (solo muestra los números).
payload = JSON.parse($stdin.read)
dry = ENV["DRY_RUN"] == "1"
stats = nil
Current.batch_id = SecureRandom.uuid
ActiveRecord::Base.transaction do
  stats = QuickbooksImportService.new(payload["rows"], payload["vendor_map"]).run
  raise ActiveRecord::Rollback if dry
end
puts "#{dry ? "PRUEBA EN SECO (revertida)" : "APLICADO"} · lote #{Current.batch_id}"
puts stats.inspect
