require "test_helper"
require "caxlsx"

class XlsxImportHelperTest < ActiveSupport::TestCase
  def write_xlsx(headers, rows)
    path = Rails.root.join("tmp", "test_xlsx_#{SecureRandom.hex(4)}.xlsx").to_s
    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: "Carga") do |sheet|
        sheet.add_row headers if headers
        rows.each { |r| sheet.add_row r }
      end
    end.serialize(path)
    path
  end

  test "lee filas normalizando encabezados y descarta filas completamente vacías" do
    path = write_xlsx(
      ["Código producto", "Cantidad"],
      [["SOF-001", 2], [nil, nil], ["SOF-002", 3]]
    )

    result = XlsxImportHelper.read_xlsx(path)

    assert_empty result[:errors]
    assert_equal 2, result[:rows].size
    assert_equal "SOF-001", result[:rows][0]["codigo_producto"]
    assert_equal "2", result[:rows][0]["cantidad"]
    assert_equal "SOF-002", result[:rows][1]["codigo_producto"]
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "reporta error cuando el archivo no tiene ni encabezados" do
    path = write_xlsx(nil, [])

    result = XlsxImportHelper.read_xlsx(path)

    assert_includes result[:errors], "El archivo está vacío."
    assert_empty result[:rows]
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "reporta error legible cuando el archivo no se puede abrir" do
    result = XlsxImportHelper.read_xlsx("/tmp/no-existe-#{SecureRandom.hex(4)}.xlsx")

    assert_equal 1, result[:errors].size
    assert_match "Error al leer el archivo Excel", result[:errors].first
  end
end
