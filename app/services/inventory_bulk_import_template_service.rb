require "caxlsx"

class InventoryBulkImportTemplateService
  HEADERS = [
    "Sala receptora (Entradas)", "Sala emisora (Salidas)",
    "Código producto", "Nombre de producto", "Cantidad", "Pedido", "Fecha del movimiento"
  ].freeze

  def self.call
    new.build
  end

  def build
    package = Axlsx::Package.new
    add_carga_sheet(package.workbook)
    add_salas_sheet(package.workbook)
    package.to_stream.read
  end

  private

  def add_carga_sheet(workbook)
    workbook.add_worksheet(name: "Carga") do |sheet|
      header_style = sheet.styles.add_style(b: true, bg_color: "DDEBF7")
      sheet.add_row HEADERS, style: header_style
      sheet.add_row ["Sala Escazú", "Sala Palmares", "SOF-001", "Sofá 3 puestos", 2, "", Date.current]
    end
  end

  def add_salas_sheet(workbook)
    workbook.add_worksheet(name: "Salas válidas") do |sheet|
      header_style = sheet.styles.add_style(b: true, bg_color: "DDEBF7")
      sheet.add_row ["Código", "Nombre"], style: header_style
      Showroom.active.order(:name).each { |s| sheet.add_row [s.code, s.name] }
    end
  end
end
