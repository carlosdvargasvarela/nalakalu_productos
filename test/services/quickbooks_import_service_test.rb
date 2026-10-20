require "test_helper"

class QuickbooksImportServiceTest < ActiveSupport::TestCase
  ROWS = [
    {"item" => "001000100", "desc" => "Mesa Uno..", "type" => "Inventory Part", "cost" => "", "price" => "1000.5", "um" => "", "vendor" => ""},
    {"item" => "001000200", "desc" => "Mesa Sin Precio", "type" => "Inventory Part", "cost" => "", "price" => "0.0", "um" => "", "vendor" => ""},
    {"item" => "005024300", "desc" => "Cama Marea Full..", "type" => "Inventory Part", "cost" => "", "price" => "500", "um" => "", "vendor" => ""},
    {"item" => "PIN100001", "desc" => "Madera Pino..", "type" => "Inventory Part", "cost" => "14160.0", "price" => "0.0", "um" => "meter (m)", "vendor" => "Ecomundo S.R.L"},
    {"item" => "TEL000001", "desc" => "Tela X", "type" => "Inventory Part", "cost" => "0.0", "price" => "0.0", "um" => "", "vendor" => "Proveedor Raro*"},
    {"item" => "ACC000001", "desc" => "Algo sin proveedor", "type" => "Inventory Part", "cost" => "10", "price" => "0.0", "um" => "unidad (und)", "vendor" => ""},
    {"item" => "SRV", "desc" => "Servicio", "type" => "Service", "cost" => "0", "price" => "0", "um" => "", "vendor" => ""}
  ].freeze
  VENDORS = {"Ecomundo S.R.L" => "Ecomundo S.R.L."}.freeze

  setup do
    Product.destroy_all
    @ok = Product.create!(name: "Mesa Uno", base_code: "001000100")
    @noprice = Product.create!(name: "Mesa Sin Precio", base_code: "001000200")
    @marea = Product.create!(name: "Cama Marea Full", base_code: "005017000", active: false)
    @gone = Product.create!(name: "Producto Fantasma", base_code: "009999999")
    @bad = Product.create!(name: "Rollos", base_code: "Plástico")
  end

  def run_import = QuickbooksImportService.new(ROWS, VENDORS).run

  test "limpia los puntos de los nombres" do
    assert_equal "Mesa de Comedor", QbItem.clean_name("Mesa de Comedor..")
    assert_equal "Silla Danta. Asiento teca.", QbItem.clean_name("Silla Danta. Asiento teca.")
    assert_equal "A B", QbItem.clean_name("A..B")
  end

  test "carga precios por código exacto y marca lo que no coincide" do
    stats = run_import
    assert_equal 1000.5, @ok.reload.list_price
    assert_nil @noprice.reload.list_price
    assert_equal "needs_changes", @noprice.review_status
    assert_match "sin precio", @noprice.review.note

    assert_match "otro código: 005024300", @marea.reload.review.note
    assert_match "(está inactivo)", @marea.review.note
    assert_match "No existe en QuickBooks", @gone.reload.review.note
    assert_match "formato de QuickBooks", @bad.reload.review.note
    assert_equal "pending", @ok.review_status, "lo que coincide queda pendiente, no marcado"
    assert_equal 4, stats[:products_flagged]
    assert_equal 1, stats[:prices_set]
  end

  test "crea piezas de proveedor pendientes con origen quickbooks y marca lo dudoso" do
    run_import
    pino = SupplierItem.find_by!(sku: "PIN100001")
    assert_equal "quickbooks", pino.source
    assert_equal "Madera Pino", pino.name
    assert_equal "Ecomundo S.R.L.", pino.provider.name, "usa el nombre de Odoo"
    assert_equal 14160, pino.default_cost
    assert_equal "metro", pino.unit
    assert_equal "pending", pino.review_status

    tela = SupplierItem.find_by!(sku: "TEL000001")
    assert_equal "Proveedor Raro", tela.provider.name, "sin equivalente: nombre de QuickBooks sin asterisco"
    assert_match "no se encontró en los contactos de Odoo", tela.review.note
    assert_match "Sin costo", tela.review.note
    assert_nil tela.default_cost

    sin = SupplierItem.find_by!(sku: "ACC000001")
    assert_equal QuickbooksImportService::NO_VENDOR, sin.provider.name
    assert_match "no tiene proveedor", sin.review.note
    assert_nil SupplierItem.find_by(sku: "SRV"), "los servicios no se importan"
  end

  test "es idempotente" do
    run_import
    before = [SupplierItem.count, Provider.count, Review.count, QbItem.count]
    stats = run_import
    assert_equal before, [SupplierItem.count, Provider.count, Review.count, QbItem.count]
    assert_equal 0, stats[:items_created]
    assert_equal 0, stats[:prices_set]
  end

  test "no pisa una revisión hecha por una persona" do
    Review.create!(reviewable: @gone, status: "approved", user: users(:revisor))
    run_import
    assert_equal "approved", @gone.reload.review_status
  end

  test "todo queda en un lote y se puede deshacer" do
    Current.batch_id = SecureRandom.uuid
    run_import
    assert_equal 1000.5, @ok.reload.list_price
    ChangeLog.undo_batch!(Current.batch_id, users(:revisor))
    assert_nil @ok.reload.list_price
    assert_nil SupplierItem.find_by(sku: "PIN100001")
    assert_equal 0, Review.where(user_id: nil).count, "las marcas automáticas también se deshacen"
  ensure
    Current.reset
  end

  test "el panel compara contra QuickBooks" do
    assert ReviewGuide.checks(@ok).none? { _1.text.include?("QuickBooks") }, "sin export cargado no verifica"
    run_import
    assert_equal :ok, ReviewGuide.checks(@ok.reload).find { _1.text.include?("Existe en QuickBooks") }.level
    assert_equal :bad, ReviewGuide.checks(@gone).find { _1.text.include?("No existe en QuickBooks") }.level
  end
end
