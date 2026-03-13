# app/jobs/import_variant_types_job.rb
class ImportVariantTypesJob < ApplicationJob
  queue_as :imports

  def perform(csv_content, user_id = nil)
    Rails.logger.info "🚀 Iniciando importación de TIPOS DE VARIANTE"

    Tempfile.create(["import_variant_types", ".csv"]) do |file|
      file.write(csv_content)
      file.rewind
      report = ImportVariantTypesService.call(file.path)
      Rails.logger.info "✅ Importación de Tipos de Variante completada: #{report.inspect}"
    end

    Rails.logger.info "👤 Ejecutada por: #{User.find_by(id: user_id)&.email}" if user_id
  end
end
