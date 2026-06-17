require "test_helper"
require "caxlsx"

class InventoryBulkImportServiceTest < ActiveSupport::TestCase
  HEADERS = [
    "Sala receptora (Entradas)", "Sala emisora (Salidas)",
    "Código producto", "Nombre de producto", "Cantidad", "Pedido", "Fecha del movimiento"
  ].freeze

  setup do
    @palmares = showrooms(:palmares)
    @escazu   = showrooms(:escazu)
    @product  = products(:one)
  end

  def write_xlsx(headers, rows)
    path = Rails.root.join("tmp", "test_bulk_service_#{SecureRandom.hex(4)}.xlsx").to_s
    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: "Carga") do |sheet|
        sheet.add_row headers if headers
        rows.each { |r| sheet.add_row r }
      end
    end.serialize(path)
    path
  end

  test "fila con solo sala receptora genera un movimiento entry resuelto por código" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", @product.base_code, @product.name, 3, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert result.sync
    assert_equal "bulk_upload", result.sync.kind
    movements = result.sync.inventory_movements
    assert_equal 1, movements.count
    m = movements.first
    assert_equal "entry", m.movement_type
    assert_equal @escazu, m.showroom
    assert_equal @product, m.product
    assert_equal "resolved", m.status
    assert_equal "manual", m.source
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "fila con solo sala emisora genera un movimiento exit" do
    path = write_xlsx(HEADERS, [["", @palmares.name, @product.base_code, @product.name, 2, "", ""]])
    result = InventoryBulkImportService.call(path)

    m = result.sync.inventory_movements.first
    assert_equal "exit", m.movement_type
    assert_equal @palmares, m.showroom
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "matchea sala por código además de por nombre" do
    path = write_xlsx(HEADERS, [[@escazu.code, "", @product.base_code, @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal @escazu, result.sync.inventory_movements.first.showroom
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "código que matchea usa ese producto e ignora el nombre de la fila" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", @product.base_code, "Nombre que no existe", 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal @product, result.sync.inventory_movements.first.product
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "sin código, el nombre exacto resuelve el producto" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "", @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal @product, result.sync.inventory_movements.first.product
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "código que no matchea no cae a buscar por nombre" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "CODIGO-INEXISTENTE", @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    m = result.sync.inventory_movements.first
    assert_nil m.product_id
    assert_equal "unresolved", m.status
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "código y nombre sin producto encontrado queda sin asignar pero la fila se conserva" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "NUEVO-001", "Producto nuevo", 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    m = result.sync.inventory_movements.first
    assert_nil m.product_id
    assert_equal "unresolved", m.status
    assert_equal "Producto nuevo", m.product_name_raw
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "sala que no existe descarta la fila y queda en import_errors" do
    path = write_xlsx(HEADERS, [["Sala que no existe", "", @product.base_code, @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 0, result.sync.inventory_movements.count
    assert_match "Sala que no existe", result.sync.import_errors.join
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "cantidad inválida o cero descarta la fila" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", @product.base_code, @product.name, 0, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 0, result.sync.inventory_movements.count
    assert_match "cantidad", result.sync.import_errors.join.downcase
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "fila sin ninguna sala indicada se descarta" do
    path = write_xlsx(HEADERS, [["", "", @product.base_code, @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 0, result.sync.inventory_movements.count
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "fila sin código ni nombre de producto se descarta" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "", "", 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 0, result.sync.inventory_movements.count
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "archivo sin columnas requeridas reporta error sin crear sync" do
    path = write_xlsx(["Columna rara"], [["x"]])
    result = InventoryBulkImportService.call(path)

    assert_nil result.sync
    assert_match "Faltan columnas", result.file_errors.join
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "archivo con encabezados válidos pero sin filas de datos no crea sync" do
    path = write_xlsx(HEADERS, [])
    result = InventoryBulkImportService.call(path)

    assert_nil result.sync
    assert result.file_errors.any?
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "fila con ambas salas genera transferencia (exit + entry) con el mismo order_number" do
    path = write_xlsx(HEADERS, [[@escazu.name, @palmares.name, @product.base_code, @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    movements = result.sync.inventory_movements.to_a
    assert_equal 2, movements.size
    assert_equal 1, movements.count { |m| m.movement_type == "exit" && m.showroom == @palmares }
    assert_equal 1, movements.count { |m| m.movement_type == "entry" && m.showroom == @escazu }
    assert_equal movements[0].order_number, movements[1].order_number
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "Pedido provisto se usa como order_number; vacío genera uno sintético por fila" do
    path = write_xlsx(HEADERS, [
      [@escazu.name, "", @product.base_code, @product.name, 1, "PED-1", ""],
      [@palmares.name, "", @product.base_code, @product.name, 1, "", ""]
    ])
    result = InventoryBulkImportService.call(path)

    movements = result.sync.inventory_movements.order(:id).to_a
    assert_equal "PED-1", movements[0].order_number
    assert_equal "CARGA-#{result.sync.id}-F3", movements[1].order_number
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "salida con stock insuficiente queda marcada con flag stock_missing" do
    path = write_xlsx(HEADERS, [["", @palmares.name, @product.base_code, @product.name, 5, "", ""]])
    result = InventoryBulkImportService.call(path)

    m = result.sync.inventory_movements.first
    assert_equal "stock_missing", m.flag
    assert_match "Alerta automática", m.notes
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "entry no se ve afectado por la validación de stock" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", @product.base_code, @product.name, 999, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_nil result.sync.inventory_movements.first.flag
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "deliveries_processed cuenta todas las filas del archivo, incluyendo descartadas" do
    path = write_xlsx(HEADERS, [
      [@escazu.name, "", @product.base_code, @product.name, 1, "", ""],
      ["Sala que no existe", "", @product.base_code, @product.name, 1, "", ""]
    ])
    result = InventoryBulkImportService.call(path)

    assert_equal 2, result.sync.deliveries_processed
    assert_equal 1, result.sync.movements_count
    assert_equal 1, result.sync.import_errors.size
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "unresolved_count refleja movimientos sin producto asignado" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "SIN-MATCH", "Producto sin match", 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 1, result.sync.unresolved_count
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
