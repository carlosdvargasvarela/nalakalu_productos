class PriceImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  def new
  end

  def template
    format = (params[:format] == "csv") ? "csv" : "xlsx"
    type = (format == "csv") ? "text/csv" : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    send_data PriceImportService.template(format), filename: "plantilla_precios.#{format}", type: type
  end

  def preview
    file = params[:file]
    return redirect_to(price_imports_path, alert: "Elige un archivo CSV o Excel (.xlsx).") if file.blank?
    unless file.original_filename.downcase.end_with?(".csv", ".xlsx")
      return redirect_to(price_imports_path, alert: "Formato no válido: usa .csv o .xlsx.")
    end

    @result = PriceImportService.preview(file.tempfile.path, file.original_filename)
  end

  def apply
    changes = JSON.parse(params[:changes].to_s)
    n = PriceImportService.apply(changes)
    redirect_to products_path, notice: "#{n} precios actualizados. Puedes deshacerlo desde el Historial."
  rescue JSON::ParserError, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, ArgumentError
    redirect_to price_imports_path, alert: "No se pudieron aplicar los precios. Sube el archivo de nuevo."
  end
end
