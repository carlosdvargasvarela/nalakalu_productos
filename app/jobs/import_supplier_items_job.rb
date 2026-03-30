# app/jobs/import_supplier_items_job.rb
class ImportSupplierItemsJob < ApplicationJob
  queue_as :imports

  def perform(file_path, user_id = nil)
    report = ImportSupplierItemsService.call(file_path)

    # Log detallado para Sidekiq/Console
    Rails.logger.info "[IMPORT] SupplierItems: C:#{report[:created]} U:#{report[:updated]} E:#{report[:errors].count}"

    # Aquí podrías disparar una notificación ActionCable o un mail al user_id si quisieras
    report
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end
end
