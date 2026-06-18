require "caxlsx"

class InventoryMovementsExportService
  HEADERS = [
    "Fecha", "Tipo", "Sala", "Producto", "Cantidad",
    "Origen", "Pedido", "Notas", "Stock faltante"
  ].freeze

  def self.call(movements)
    new(movements).build
  end

  def initialize(movements)
    @movements = movements
  end

  def build
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Movimientos") do |sheet|
      header_style = sheet.styles.add_style(b: true, bg_color: "DDEBF7")
      sheet.add_row HEADERS, style: header_style
      @movements.each { |m| sheet.add_row row_for(m) }
    end
    package.to_stream.read
  end

  private

  def row_for(m)
    [
      m.delivery_date&.strftime("%d/%m/%Y"),
      m.type_label,
      m.showroom&.name || "—",
      m.product&.name || m.product_name_raw || "—",
      m.quantity,
      (m.source == "manual") ? "Manual" : "Sync",
      m.order_number,
      m.notes,
      (m.flag == "stock_missing") ? "Sí" : "No"
    ]
  end
end
