class ImportVariantsJob < ApplicationJob
  queue_as :imports

  def perform(file_path, user_id = nil)
    Rails.logger.info "🚀 Iniciando importación de VARIANTES: #{file_path}"

    report = ImportVariantsService.call(file_path)

    Rails.logger.info "✅ Importación de Variantes completada: #{report.inspect}"

    if user_id
      user = User.find_by(id: user_id)
      Rails.logger.info "👤 Ejecutada por: #{user&.email}"
    end
  ensure
    if file_path.start_with?(Rails.root.join("tmp").to_s) && File.exist?(file_path)
      File.delete(file_path)
      Rails.logger.info "🗑️ Archivo temporal de variantes eliminado"
    end
  end
end
