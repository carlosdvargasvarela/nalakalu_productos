class ImportProductsJob < ApplicationJob
  queue_as :imports

  def perform(file_path, user_id = nil)
    Rails.logger.info "🚀 Iniciando importación de productos: #{file_path}"

    report = ImportProductsService.call(file_path)

    Rails.logger.info "✅ Importación completada — " \
      "Creados: #{report[:created]}, " \
      "Actualizados: #{report[:updated]}, " \
      "Errores: #{report[:errors].count}"

    if user_id
      user = User.find_by(id: user_id)
      Rails.logger.info "👤 Ejecutada por: #{user&.email}"
    end

    report
  ensure
    if file_path.start_with?(Rails.root.join("tmp").to_s) && File.exist?(file_path)
      File.delete(file_path)
      Rails.logger.info "🗑️  Archivo temporal eliminado"
    end
  end
end
