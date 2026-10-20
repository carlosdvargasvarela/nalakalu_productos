# Aplica las decisiones del triaje. Lee el JSON de quickbooks_triage_prepare.rb por stdin. DRY_RUN=1 revierte al final.
#   Local:  bin/rails runner scripts/quickbooks_triage_apply.rb < tmp/triaje_decisiones.json
#   Heroku: heroku run --no-tty -a nalakalu-productos "rails runner scripts/quickbooks_triage_apply.rb" < tmp/triaje_decisiones.json
decisions = JSON.parse($stdin.read)
dry = ENV["DRY_RUN"] == "1"
stats = notes = nil
Current.batch_id = SecureRandom.uuid
ActiveRecord::Base.transaction do
  stats, notes = QuickbooksTriageService.new(decisions).run
  raise ActiveRecord::Rollback if dry
end
puts "#{dry ? "PRUEBA EN SECO (revertida)" : "APLICADO"} · lote #{Current.batch_id}"
puts stats.inspect
notes.each { puts "  · #{_1}" }
