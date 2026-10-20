require "test_helper"

class QuickbooksTriageServiceTest < ActiveSupport::TestCase
  setup do
    Product.destroy_all
    QbItem.create!(code: "005024300", description: "Cama Marea Full", raw_description: "Cama Marea Full..", item_type: "Inventory Part", price: 542035.0)
    @old = Product.create!(name: "Cama Marea Full", base_code: "005017000")
    @hidden = Product.create!(name: "Cama Silvia", base_code: "005011300", active: false)
    @gone = Product.create!(name: "Rollos", base_code: "Plástico")
    @keep = Product.create!(name: "Cómoda Pacífica", base_code: "007004200")
    [@old, @hidden, @gone, @keep].each { Review.create!(reviewable: _1, status: "needs_changes", note: "No existe en QuickBooks") }
    @decisions = {"cambiar" => [{"code" => "005017000", "new_code" => "005024300"}], "ocultar" => ["005011300"], "eliminar" => ["Plástico"], "revisar" => ["007004200"]}
  end

  def run_it = QuickbooksTriageService.new(@decisions).run

  test "cambia el código al de QuickBooks, toma su precio y cierra la marca automática" do
    stats, = run_it
    assert_equal "005024300", @old.reload.base_code
    assert_equal 542035, @old.list_price
    assert_equal "pending", @old.review_status
    assert_nil @old.review.note
    assert_equal 1, stats[:codigos_cambiados]
  end

  test "oculta y resuelve; elimina; lo de revisar no se toca" do
    stats, = run_it
    assert_not @hidden.reload.active
    assert_equal "approved", @hidden.review_status
    assert_match "decidió ocultarlo", @hidden.review.note
    assert_nil Product.find_by(base_code: "Plástico")
    assert_equal "needs_changes", @keep.reload.review_status, "«Revisar» queda marcado"
    assert_equal({ocultar_ya_inactivos: 1, eliminados: 1, revisar_pendientes: 1}, stats.slice(:ocultar_ya_inactivos, :eliminados, :revisar_pendientes))
  end

  test "no cambia el código si el nuevo ya existe" do
    Product.create!(name: "Otro", base_code: "005024300")
    stats, notes = run_it
    assert_equal "005017000", @old.reload.base_code
    assert_equal 1, stats[:cambiar_codigo_ocupado]
    assert_match "ya existe un producto con ese código", notes.join
  end

  test "no pisa una revisión hecha por una persona" do
    @hidden.review.update!(status: "approved", user: users(:revisor), note: "ok")
    run_it
    assert_equal "ok", @hidden.reload.review.note
  end

  test "es idempotente" do
    run_it
    snapshot = [Product.count, Product.pluck(:base_code).sort, Review.pluck(:status).sort]
    stats, = run_it
    assert_equal snapshot, [Product.count, Product.pluck(:base_code).sort, Review.pluck(:status).sort]
    assert_equal 0, stats[:codigos_cambiados].to_i
    assert_equal 0, stats[:eliminados].to_i
  end

  test "agregar crea el producto con su familia y precio; no duplica" do
    fam = Family.create!(name: "Mesas de Comedor")
    @decisions = {"agregar" => [{"code" => "001000100", "name" => "Mesa Alemana..", "price" => "129700.0", "family" => "Mesas de Comedor"}]}
    stats, = run_it
    p = Product.find_by!(base_code: "001000100")
    assert_equal [fam.id, "Mesa Alemana", 129700], [p.family_id, p.name, p.list_price]
    assert_equal 1, stats[:agregados]
    stats, = run_it
    assert_equal 1, stats[:agregar_ya_existe]
  end

  test "todo queda en un lote y se deshace" do
    Current.batch_id = SecureRandom.uuid
    run_it
    ChangeLog.undo_batch!(Current.batch_id, users(:revisor))
    assert_equal "005017000", @old.reload.base_code
    assert Product.exists?(base_code: "Plástico")
    assert_equal "needs_changes", @hidden.reload.review_status
  ensure
    Current.reset
  end

  test "eliminar no borra historial de módulos ocultos: lo deja inactivo y avisa" do
    InventoryMovement.create!(product: @gone, movement_type: "entry", quantity: 1, showroom: showrooms(:palmares))
    stats, notes = run_it
    assert Product.exists?(@gone.id), "no se borra"
    assert_not @gone.reload.active
    assert_equal 0, stats[:eliminados].to_i
    assert_equal 1, stats[:eliminar_bloqueado]
    assert_match "movimientos de inventario", notes.join
    assert_equal 1, InventoryMovement.where(product_id: @gone.id).count
    assert_equal "005024300", @old.reload.base_code, "el resto de las decisiones se aplicó igual"
  end
end
