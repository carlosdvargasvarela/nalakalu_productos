require "test_helper"

class BulkActionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:revisor)
    @a = Product.create!(name: "A", base_code: "A1")
    @b = Product.create!(name: "B", base_code: "B1")
    @c = Product.create!(name: "C", base_code: "C1")
  end

  def last_batch(type) = ChangeLog.where(record_type: type).order(:id).last.batch_id

  test "aprobar en masa y deshacer todo en un paso" do
    post bulk_url("product"), params: {ids: [@a.id, @b.id], bulk_action: "approve"}
    assert_equal %w[approved approved pending], [@a, @b, @c].map { _1.reload.review_status }
    post undo_change_url(last_batch("Review"))
    assert_equal %w[pending pending pending], [@a, @b, @c].map { _1.reload.review_status }
    assert_equal 0, Review.count
  end

  test "pedir cambios exige comentario" do
    post bulk_url("product"), params: {ids: [@a.id], bulk_action: "needs_changes", note: ""}
    assert_equal "pending", @a.reload.review_status
    post bulk_url("product"), params: {ids: [@a.id, @b.id], bulk_action: "needs_changes", note: "Falta precio"}
    assert_equal ["needs_changes"] * 2, [@a, @b].map { _1.reload.review_status }
    assert_equal "Falta precio", @a.review.note
  end

  test "ocultar y activar" do
    post bulk_url("product"), params: {ids: [@a.id, @b.id], bulk_action: "hide"}
    assert_equal [false, false, true], [@a, @b, @c].map { _1.reload.active }
    post bulk_url("product"), params: {ids: [@a.id], bulk_action: "show"}
    assert @a.reload.active
  end

  test "eliminar pide confirmación, muestra el impacto y es deshacible" do
    tipo = VariantType.create!(name: "Textiles")
    2.times { |i| Variant.create!(variant_type: tipo, name: "T#{i}", active: false) }
    otro = VariantType.create!(name: "Maderas")
    Variant.create!(variant_type: otro, name: "M1", active: false)

    post bulk_url("variant_type"), params: {ids: [tipo.id, otro.id], bulk_action: "delete"}
    assert_response :success
    assert_match "Eliminar 2 tipos de variante", response.body
    assert_select ".badge.bg-danger", text: "3" # 3 variantes se eliminan junto con los tipos

    assert VariantType.exists?(tipo.id), "sin confirmar no se borra"

    post bulk_url("variant_type"), params: {ids: [tipo.id, otro.id], bulk_action: "delete", confirmed: "1"}
    assert_not VariantType.exists?(tipo.id)
    assert_equal 0, Variant.where(name: %w[T0 T1 M1]).count

    post undo_change_url(last_batch("VariantType"))
    assert VariantType.exists?(tipo.id) && VariantType.exists?(otro.id)
    assert_equal 3, Variant.where(name: %w[T0 T1 M1]).count
  end

  test "asignar y quitar familia conserva las reglas y se deshace" do
    fam = Family.create!(name: "Mesas")
    rule = @a.product_variant_rules.create!(variant_type: variant_types(:one), position: 1)
    post bulk_url("product"), params: {ids: [@a.id, @b.id], bulk_action: "assign_family", target_id: fam.id}
    assert_equal [fam.id, fam.id], [@a, @b].map { _1.reload.family_id }
    assert_equal [rule.id], @a.product_variant_rules.pluck(:id)
    post undo_change_url(last_batch("Product"))
    assert_equal [nil, nil], [@a, @b].map { _1.reload.family_id }
    post bulk_url("product"), params: {ids: [@a.id], bulk_action: "unassign_family"}
    assert_nil @a.reload.family_id
  end

  test "mover variantes de tipo y piezas de proveedor" do
    t1, t2 = VariantType.create!(name: "T1"), VariantType.create!(name: "T2")
    v = Variant.create!(variant_type: t1, name: "V", active: false)
    post bulk_url("variant"), params: {ids: [v.id], bulk_action: "move_type", target_id: t2.id}
    assert_equal t2.id, v.reload.variant_type_id

    item = SupplierItem.create!(provider: providers(:one), name: "P")
    post bulk_url("supplier_item"), params: {ids: [item.id], bulk_action: "move_provider", target_id: providers(:two).id}
    assert_equal providers(:two).id, item.reload.provider_id
  end

  test "seleccionar todos los resultados usa all_ids" do
    post bulk_url("product"), params: {all_mode: "1", all_ids: [@a.id, @b.id, @c.id].join(","), ids: [@a.id], bulk_action: "approve"}
    assert_equal %w[approved] * 3, [@a, @b, @c].map { _1.reload.review_status }
  end

  test "acción inválida o sin selección no hace nada" do
    post bulk_url("product"), params: {ids: [@a.id], bulk_action: "explotar"}
    post bulk_url("product"), params: {bulk_action: "approve"}
    assert_equal 0, Review.count
  end

  test "las listas muestran casillas y la barra de acciones con todos los ids del filtro" do
    get products_url
    assert_select "input[type=checkbox][name='ids[]'][form=bulk-form]", minimum: 3
    assert_select "[data-controller=bulk-actions][data-bulk-actions-all-ids-value]"
    assert_select "button[name=bulk_action][value=assign_family]"
    get supplier_items_url
    assert_select "button[name=bulk_action][value=move_provider]"
  end

  test "all_ids no duplica ids aunque el producto tenga muchas reglas y piezas" do
    2.times { |i| @a.product_variant_rules.create!(variant_type: VariantType.create!(name: "T#{i}"), position: i) }
    get products_url(review: "pending")
    ids = JSON.parse(css_select("[data-bulk-actions-all-ids-value]").first["data-bulk-actions-all-ids-value"])
    assert_equal ids.uniq, ids
    assert_equal Product.count, ids.size
  end

  test "los botones no cambian de destino (el token CSRF es por formulario) y el borrado funciona con CSRF activo" do
    ActionController::Base.allow_forgery_protection = true
    get products_url
    assert_select "#bulk-form button[formaction]", count: 0
    token = css_select("#bulk-form input[name=authenticity_token]").first["value"]
    post bulk_url("product"), params: {authenticity_token: token, ids: [@a.id], bulk_action: "delete"}
    assert_response :success
    assert_match "Eliminar 1 producto", response.body
    assert Product.exists?(@a.id)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "vuelve a la lista de origen con sus filtros, nunca a la pantalla de confirmación" do
    post bulk_url("product"), params: {ids: [@a.id], bulk_action: "hide", return_to: "/products?filter=no_price"}
    assert_redirected_to "/products?filter=no_price"

    # flujo completo: lista -> confirmación -> eliminar; el Referer es la confirmación (solo POST)
    post bulk_url("product"), params: {ids: [@b.id], bulk_action: "delete", return_to: "/products?review=pending"}
    assert_match "/products?review=pending", css_select("input[name=return_to]").first["value"]
    post bulk_url("product"), params: {ids: [@b.id], bulk_action: "delete", confirmed: "1", return_to: "/products?review=pending"},
      headers: {"HTTP_REFERER" => "http://www.example.com/masivo/product"}
    assert_redirected_to "/products?review=pending"
    assert_not Product.exists?(@b.id)
  end

  test "return_to solo acepta rutas internas" do
    post bulk_url("product"), params: {ids: [@a.id], bulk_action: "hide", return_to: "https://malo.example/robar"}
    assert_redirected_to products_path
    post bulk_url("product"), params: {ids: [@a.id], bulk_action: "show", return_to: "//malo.example"}
    assert_redirected_to products_path
  end
end
