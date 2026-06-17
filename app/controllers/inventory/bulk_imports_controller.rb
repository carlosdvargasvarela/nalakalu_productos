class Inventory::BulkImportsController < Inventory::BaseController
  def new
  end

  def create
    unless params[:file].present?
      redirect_to new_inventory_bulk_import_path, alert: "Selecciona un archivo .xlsx."
      return
    end

    tmp_path = Rails.root.join("tmp", "bulk_import_#{Time.now.to_i}_#{SecureRandom.hex(4)}.xlsx")
    FileUtils.cp(params[:file].tempfile.path, tmp_path)

    result = InventoryBulkImportService.call(tmp_path.to_s)

    if result.sync
      notice = "Carga procesada: #{result.sync.movements_count} movimiento(s) generado(s)."
      notice += " #{result.sync.import_errors.size} fila(s) con error fueron omitidas." if result.sync.import_errors.any?
      redirect_to inventory_sync_path(result.sync), notice: notice
    else
      redirect_to new_inventory_bulk_import_path, alert: result.file_errors.join("; ")
    end
  ensure
    File.delete(tmp_path) if tmp_path && File.exist?(tmp_path)
  end

  def template
    send_data InventoryBulkImportTemplateService.call,
      filename: "plantilla_carga_masiva_inventario.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end
end
