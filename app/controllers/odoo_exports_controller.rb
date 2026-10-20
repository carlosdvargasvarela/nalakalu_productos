class OdooExportsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  def index
    @files = OdooExportService.call.transform_values { |body| body.lines.size - 1 }
  end

  def show
    body = OdooExportService.call[params[:file]]
    return head :not_found unless body

    send_data body, filename: params[:file], type: "text/csv"
  end
end
