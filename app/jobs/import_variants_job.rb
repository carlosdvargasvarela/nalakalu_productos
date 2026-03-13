# app/jobs/import_variants_job.rb
class ImportVariantsJob < ApplicationJob
  queue_as :imports

  def perform(csv_content, user_id = nil)
    Rails.logger.info "🚀 Iniciando importación de VARIANTES"

    Tempfile.create(["import_variants", ".csv"]) do |file|
      file.write(csv_content)
      file.rewind
      report = ImportVariantsService.call(file.path)
      Rails.logger.info "✅ Importación de Variantes completada: #{report.inspect}"
    end

    Rails.logger.info "👤 Ejecutada por: #{User.find_by(id: user_id)&.email}" if user_id
  end
end