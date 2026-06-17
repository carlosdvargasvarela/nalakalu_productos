require "test_helper"
require "roo"

class InventoryBulkImportTemplateServiceTest < ActiveSupport::TestCase
  test "genera un xlsx con los encabezados esperados y las salas activas" do
    inactive = Showroom.create!(name: "Bodega vieja", code: "BV", active: false)

    content = InventoryBulkImportTemplateService.call

    path = Rails.root.join("tmp", "test_template_#{SecureRandom.hex(4)}.xlsx").to_s
    File.binwrite(path, content)

    carga = Roo::Excelx.new(path).sheet(0)
    assert_equal [
      "Sala receptora (Entradas)", "Sala emisora (Salidas)",
      "Código producto", "Nombre de producto", "Cantidad", "Pedido", "Fecha del movimiento"
    ], carga.row(1)

    salas = Roo::Excelx.new(path).sheet(1)
    codes = (2..salas.last_row).map { |i| salas.row(i).first }
    assert_includes codes, showrooms(:palmares).code
    assert_not_includes codes, inactive.code
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
