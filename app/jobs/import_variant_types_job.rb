class ImportVariantTypesJob < ApplicationJob
  queue_as :imports

  def perform(file_path, user_id = nil)
    Rails.logger.info "🚀 Iniciando importación de TIPOS DE VARIANTE: #{file_path}"

    report = ImportVariantTypesService.call(file_path)

    Rails.logger.info "✅ Importación de Tipos de Variante completada: #{report.inspect}"

    if user_id
      user = User.find_by(id: user_id)
      Rails.logger.info "👤 Ejecutada por: #{user&.email}"
    end
  ensure
    # Limpieza garantizada del archivo temporal
    if file_path.start_with?(Rails.root.join("tmp").to_s) && File.exist?(file_path)
      File.delete(file_path)
      Rails.logger.info "🗑️ Archivo temporal de tipos de variante eliminado"
    end
  end
end
