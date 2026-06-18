require "test_helper"
require "roo"

class InventoryMovementsExportServiceTest < ActiveSupport::TestCase
  test "genera un xlsx con encabezados y filas de los movimientos dados" do
    showroom = showrooms(:palmares)
    product = products(:one)
    movement = InventoryMovement.create!(
      movement_type: "exit", source: "manual", status: "resolved",
      product: product, showroom: showroom, quantity: 3,
      delivery_date: Date.new(2026, 1, 15), order_number: "2-00123", notes: "Nota de prueba",
      flag: "stock_missing"
    )

    content = InventoryMovementsExportService.call(InventoryMovement.where(id: movement.id))

    path = Rails.root.join("tmp", "test_movements_export_#{SecureRandom.hex(4)}.xlsx").to_s
    File.binwrite(path, content)

    sheet = Roo::Excelx.new(path).sheet(0)
    assert_equal [
      "Fecha", "Tipo", "Sala", "Producto", "Cantidad",
      "Origen", "Pedido", "Notas", "Stock faltante"
    ], sheet.row(1)

    row = sheet.row(2)
    assert_equal "15/01/2026", row[0]
    assert_equal showroom.name, row[2]
    assert_equal product.name, row[3]
    assert_equal 3, row[4]
    assert_equal "Manual", row[5]
    assert_equal "2-00123", row[6]
    assert_equal "Nota de prueba", row[7]
    assert_equal "Sí", row[8]
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
