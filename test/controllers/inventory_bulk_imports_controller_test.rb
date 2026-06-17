# test/controllers/inventory_bulk_imports_controller_test.rb
require "test_helper"
require "caxlsx"

class InventoryBulkImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @escazu  = showrooms(:escazu)
    @product = products(:one)
  end

  def write_xlsx(headers, rows)
    path = Rails.root.join("tmp", "test_bulk_controller_#{SecureRandom.hex(4)}.xlsx").to_s
    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: "Carga") do |sheet|
        sheet.add_row headers if headers
        rows.each { |r| sheet.add_row r }
      end
    end.serialize(path)
    path
  end

  test "should get new" do
    get new_inventory_bulk_import_url
    assert_response :success
  end

  test "descarga la plantilla en formato xlsx" do
    get inventory_bulk_import_template_url
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", @response.media_type
  end

  test "procesa un archivo válido y redirige a la revisión del sync creado" do
    headers = [
      "Sala receptora (Entradas)", "Sala emisora (Salidas)",
      "Código producto", "Nombre de producto", "Cantidad", "Pedido", "Fecha del movimiento"
    ]
    path = write_xlsx(headers, [[@escazu.name, "", @product.base_code, @product.name, 3, "", ""]])

    assert_difference("InventorySync.count", 1) do
      assert_difference("InventoryMovement.count", 1) do
        post inventory_bulk_imports_url, params: {
          file: Rack::Test::UploadedFile.new(path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        }
      end
    end

    sync = InventorySync.order(:created_at).last
    assert_equal "bulk_upload", sync.kind
    assert_redirected_to inventory_sync_path(sync)
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "archivo sin columnas requeridas vuelve al formulario con error y sin crear sync" do
    path = write_xlsx(["Columna rara"], [["x"]])

    assert_no_difference("InventorySync.count") do
      post inventory_bulk_imports_url, params: {
        file: Rack::Test::UploadedFile.new(path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      }
    end

    assert_redirected_to new_inventory_bulk_import_path
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "sin archivo adjunto vuelve al formulario con error" do
    post inventory_bulk_imports_url, params: {}
    assert_redirected_to new_inventory_bulk_import_path
  end
end
