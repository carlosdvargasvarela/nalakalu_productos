require "test_helper"

class PriceImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:revisor)
    @a = Product.create!(name: "Mesa A", base_code: "AAA", list_price: 100)
    @b = Product.create!(name: "Mesa B", base_code: "BBB")
  end

  test "parse_price entiende los formatos habituales" do
    {"450000" => 450000, "450.000" => 450000, "450.000,50" => 450000.5, "450,000.50" => 450000.5, "₡ 450.000" => 450000,
     "1,5" => 1.5, "12.5" => 12.5, "1.500.000" => 1500000, "abc" => nil, "" => nil, "-5" => nil}.each do |raw, expected|
      got = PriceImportService.parse_price(raw)
      expected.nil? ? assert_nil(got, "parse #{raw.inspect}") : assert_equal(expected.to_d, got, "parse #{raw.inspect}")
    end
  end

  test "csv: vista previa y aplicar, todo en un lote deshacible" do
    csv = "Código base,Producto,Precio\nAAA,x,150\nBBB,y,\"1.234,5\"\nZZZ,z,10\nAAA,x,abc\n"
    post price_preview_url, params: {file: upload("p.csv", csv, "text/csv")}
    assert_response :success
    assert_match "no existe un producto con código «ZZZ»", response.body
    assert_match "precio no válido «abc»", response.body
    assert_nil @b.reload.list_price, "la vista previa no escribe"

    changes = [{id: @a.id, new: "150"}, {id: @b.id, new: "1234.5"}].to_json
    post price_apply_url, params: {changes: changes}
    assert_equal 150, @a.reload.list_price
    assert_equal 1234.5, @b.reload.list_price
    batch = ChangeLog.where(record_type: "Product", record_id: @a.id).last.batch_id
    post undo_change_url(batch)
    assert_equal 100, @a.reload.list_price
    assert_nil @b.reload.list_price
  end

  test "excel: la plantilla sirve de archivo de carga" do
    get price_template_url(format: "xlsx")
    assert_response :success

    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Precios") do |s|
      s.add_row ["Código base", "Producto", "Precio"]
      s.add_row ["AAA", "Mesa A", 100]   # igual al actual
      s.add_row ["BBB", "Mesa B", 999]
    end
    post price_preview_url, params: {file: upload("p.xlsx", package.to_stream.read, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")}
    assert_response :success
    assert_match "1 cambios", response.body
    assert_match "1 sin cambio", response.body
  end

  test "archivo sin las columnas pide usar la plantilla" do
    post price_preview_url, params: {file: upload("p.csv", "a,b\n1,2\n", "text/csv")}
    assert_match "No encontré las columnas", response.body
  end

  private

  def upload(name, content, type)
    file = Tempfile.new([File.basename(name, ".*"), File.extname(name)], binmode: true)
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type, true, original_filename: name)
  end
end
